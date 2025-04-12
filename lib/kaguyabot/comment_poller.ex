defmodule Kaguyabot.CommentPoller do
  use GenServer
  require Logger

  @subreddit "kaguya"
  # Matches either {{...}} or { ... } (non-greedy for the inner content)
  @trigger_regex ~r/\{\{([^}]+)\}\}|\{([^}]+)\}/

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    schedule_poll()
    {:ok, state}
  end

  def handle_info(:poll, state) do
    case fetch_comments() do
      {:ok, comments} ->
        # It's more efficient to fetch the token once per poll.
        with {:ok, token} <- fetch_access_token() do
          Enum.each(comments, fn comment ->
            maybe_handle_comment(comment, token)
          end)
        else
          error ->
            Logger.error("Failed to fetch token: #{inspect(error)}")
        end

      {:error, reason} ->
        Logger.error("Failed to fetch comments: #{inspect(reason)}")
    end

    schedule_poll()
    {:noreply, state}
  end

  defp schedule_poll do
    # poll every 5 seconds
    Process.send_after(self(), :poll, 5000)
  end

  defp fetch_comments do
    with {:ok, token} <- fetch_access_token() do
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
  end

  defp maybe_handle_comment(%{"body" => body, "id" => id, "author" => author}, token) do
    # Use Regex.scan to support multiple trigger occurrences in one comment.
    case Regex.scan(@trigger_regex, body) do
      [] ->
        :ignore

      matches ->
        Enum.each(matches, fn match ->
          # Extract the matched group. Either group 1 or 2 will be non-nil.
          raw_query = Enum.find(match, fn group -> group != nil and group != "" end)
          # Clean user input: trim spaces and trailing punctuation.
          book_query = raw_query |> String.trim() |> String.trim_trailing("`")
          Logger.info("Matched comment by #{author}: #{book_query}")

          case Kaguyabot.GraphQLClient.search_books(book_query) do
            {:ok, response} ->
              books = get_in(response, ["data", "search_books", "items"]) || []

              reply =
                if books == [] do
                  "Sorry, couldn't find any matching books for **#{book_query}**."
                else
                  format_reply(books)
                end

              Logger.info("Reply: #{reply}")

              # Build Reddit thing_id using the comment id: Reddit IDs for comments are prefixed with "t1_".
              parent_id = "t1_" <> id

              case post_reply(token, parent_id, reply) do
                {:ok, %{status: 200}} ->
                  Logger.info("✅ Replied to comment #{parent_id}")

                {:ok, %{status: status}} ->
                  Logger.error("❌ Failed to reply (status: #{status}) for comment #{parent_id}")

                {:error, err} ->
                  Logger.error("❌ Error posting reply for comment #{parent_id}: #{inspect(err)}")
              end

            {:error, error} ->
              Logger.error("Error searching books for '#{book_query}': #{inspect(error)}")
          end
        end)
    end
  end

  defp format_reply([]), do: "Sorry, couldn't find any matching books."

  defp format_reply([first_book | _]) do
    id = first_book["id"]
    title = first_book["title"]
    slug = first_book["slug"]
    fallback_authors = first_book["authors"] || ["Unknown author"]

    case Kaguyabot.GraphQLClient.get_book_details(id) do
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

        num_pages =
          case book_details["numPages"] do
            nil -> "?"
            p -> p
          end

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
      {:ok, %{status: 200, body: %{"access_token" => token}}} ->
        {:ok, token}

      error ->
        {:error, error}
    end
  end

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
        # Use the correct thing_id format (e.g., "t1_commentid")
        thing_id: parent_id,
        text: reply
      }
    )
  end
end
