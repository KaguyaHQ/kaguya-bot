defmodule Kaguyabot.CommentPoller do
  use GenServer
  require Logger

  alias Kaguyabot.{Repo, CommentInvocation, GraphQLClient}
  import Ecto.Query

  @subreddit "kaguya"
  # Matches either {{...}} or { ... } (non-greedy for the inner content)
  @trigger_regex ~r/\{\{([^}]+)\}\}|\{([^}]+)\}/

  ## Public API

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{})

  def init(state) do
    schedule_poll()
    {:ok, state}
  end

  def handle_info(:poll, state) do
    with {:ok, token} <- fetch_access_token(),
         {:ok, comments} <- fetch_comments(token) do
      Enum.each(comments, &maybe_handle_comment(&1, token))
    else
      {:error, error} ->
        Logger.error("Polling error: #{inspect(error)}")
    end

    schedule_poll()
    {:noreply, state}
  end

  ## Private Helpers

  # Schedule next poll in 5 seconds
  defp schedule_poll, do: Process.send_after(self(), :poll, 5000)

  # Fetch the Reddit access token
  defp fetch_access_token do
    reddit = Application.get_env(:kaguyabot, :reddit)
    userinfo = "#{reddit[:client_id]}:#{reddit[:client_secret]}"

    Req.post("https://www.reddit.com/api/v1/access_token",
      auth: {:basic, userinfo},
      form: %{
        grant_type: "password",
        username: reddit[:username],
        password: reddit[:password]
      },
      headers: [{"User-Agent", reddit[:user_agent]}]
    )
    |> case do
      {:ok, %{status: 200, body: %{"access_token" => token}}} -> {:ok, token}
      error -> {:error, error}
    end
  end

  # Fetch comments from the target subreddit using the provided token
  defp fetch_comments(token) do
    reddit = Application.get_env(:kaguyabot, :reddit)

    Req.get("https://oauth.reddit.com/r/#{@subreddit}/comments.json",
      headers: [
        {"Authorization", "Bearer #{token}"},
        {"User-Agent", reddit[:user_agent]}
      ]
    )
    |> case do
      {:ok, %{status: 200, body: %{"data" => %{"children" => comments}}}} ->
        {:ok, Enum.map(comments, & &1["data"])}

      error ->
        {:error, error}
    end
  end

  # Process an individual comment if it hasn’t been handled before
  defp maybe_handle_comment(%{"body" => body, "id" => id, "author" => author}, token) do
    if Repo.exists?(from(ci in CommentInvocation, where: ci.comment_id == ^id)) do
      Logger.info("Already handled comment #{id}, skipping.")
    else
      process_comment_triggers(body, id, author, token)
    end
  end

  # Extract matching triggers and process each one
  defp process_comment_triggers(body, id, author, token) do
    case Regex.scan(@trigger_regex, body) do
      [] ->
        :ignore

      matches ->
        matches
        |> Enum.each(fn match ->
          match
          |> Enum.find(&(&1 && &1 != ""))
          |> String.trim()
          |> String.trim_trailing("`")
          |> then(fn book_query ->
            Logger.info("Matched comment by #{author}: #{book_query}")
            handle_book_query(book_query, id, author, token)
          end)
        end)
    end
  end

  # Search for books and reply accordingly
  defp handle_book_query(book_query, comment_id, author, token) do
    case GraphQLClient.search_books(book_query) do
      {:ok, response} ->
        books = get_in(response, ["data", "search_books", "items"]) || []

        reply =
          if books == [] do
            "Sorry, couldn't find any matching books for **#{book_query}**."
          else
            format_reply(books)
          end

        Logger.info("Reply: #{reply}")

        parent_id = "t1_#{comment_id}"

        post_reply(token, parent_id, reply)
        |> case do
          {:ok, %{status: 200}} ->
            Logger.info("✅ Replied to comment #{parent_id}")
            mark_invocation(comment_id, books, author, true, reply_status(books))

          {:ok, %{status: status}} ->
            Logger.error("❌ Failed to reply (status: #{status}) for comment #{parent_id}")
            mark_invocation(comment_id, nil, author, false, "Failed with status: #{status}")

          {:error, err} ->
            Logger.error("❌ Error posting reply for comment #{parent_id}: #{inspect(err)}")
            mark_invocation(comment_id, nil, author, false, "Error: #{inspect(err)}")
        end

      {:error, error} ->
        Logger.error("Error searching books for '#{book_query}': #{inspect(error)}")
        mark_invocation(comment_id, nil, author, false, "GraphQL error: #{inspect(error)}")
    end
  end

  defp reply_status(books), do: if(books == [], do: "book not found", else: "success")

  # Mark the invocation by inserting a record into the database
  defp mark_invocation(comment_id, books, invoked_by, responded, note) do
    book_id =
      case books do
        [%{"id" => id} | _] -> id
        _ -> nil
      end

    record = %CommentInvocation{
      comment_id: comment_id,
      book_id: book_id,
      subreddit: @subreddit,
      invoked_by: invoked_by,
      invoked_at: DateTime.utc_now(),
      responded: responded,
      note: note
    }

    case Repo.insert(record, on_conflict: :nothing) do
      {:ok, _record} ->
        :ok

      {:error, error} ->
        Logger.error("Failed to insert invocation: #{inspect(error)}")
    end
  end

  # Format the reply based on book details
  defp format_reply([]), do: "Sorry, couldn't find any matching books."

  defp format_reply([first_book | _]) do
    id = first_book["id"]
    title = first_book["title"]
    slug = first_book["slug"]
    fallback_authors = first_book["authors"] || ["Unknown author"]

    case GraphQLClient.get_book_details(id) do
      {:ok, book_details} ->
        authors =
          book_details["authors"]
          |> Enum.map(& &1["name"])
          |> Enum.join(", ")

        tags =
          book_details["tags"]
          |> Enum.map(& &1["name"])
          |> Enum.join(", ")

        year =
          case book_details["originalPublicationDate"] do
            nil -> "?"
            date -> Date.from_iso8601!(date).year
          end

        num_pages = book_details["numPages"] || "?"

        description =
          book_details["description"]
          |> to_string()
          |> String.split("\n")
          |> List.first()
          |> String.slice(0..400)

        """
        **[#{title}](https://kaguya.io/books/#{slug})**
        By: #{authors} | #{num_pages} pages | Published: #{year}
        Tags: #{tags}

        > #{description}

        _(This book was requested on Reddit)_ 🌸 [Built with Kaguya](https://kaguya.io)
        """

      _ ->
        authors = Enum.join(fallback_authors, ", ")
        "I found: **#{title}** by #{authors}. Check it out here: https://kaguya.io/books/#{slug}"
    end
  end

  # Post the reply to Reddit
  defp post_reply(token, parent_id, reply) do
    reddit = Application.get_env(:kaguyabot, :reddit)

    Req.post("https://oauth.reddit.com/api/comment",
      headers: [
        {"Authorization", "Bearer #{token}"},
        {"User-Agent", reddit[:user_agent]},
        {"Content-Type", "application/x-www-form-urlencoded"}
      ],
      form: %{
        api_type: "json",
        thing_id: parent_id,
        text: reply
      }
    )
  end
end
