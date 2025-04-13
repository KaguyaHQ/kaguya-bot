defmodule Kaguyabot.GraphQLClient do
  @moduledoc "A minimal client to call the Kaguya GraphQL API."

  @graphql_endpoint "https://api.kaguya.io/graphql"
  @headers [{"Content-Type", "application/json"}]
  require Logger

  @search_books_query """
  query SearchBooks($title: String!) {
    search_books(title: $title) {
      items {
        id
      }
    }
  }
  """

  def search_books(title) do
    variables = %{"title" => title}
    body = %{query: @search_books_query, variables: variables}

    case Req.post(@graphql_endpoint,
           json: body,
           headers: @headers,
           receive_timeout: 4_000,
           retry: :transient
         ) do
      {:ok, %{status: 200, body: %{"data" => _} = response_body}} ->
        {:ok, response_body}

      {:ok, %{status: 200, body: %{"errors" => errors}}} ->
        Logger.error("GraphQL search_books error: #{inspect(errors)}")
        {:error, :graphql_error}

      error ->
        Logger.error("GraphQL search_books request failed: #{inspect(error)}")
        error
    end
  end

  @book_details_query """
  query GetBookMeta($id: ID!) {
    book(id: $id) {
      title
      slug
      description
      numPages
      originalPublicationDate
      authors { name }
      tags { name }
    }
  }
  """

  def get_book_details(id) do
    variables = %{"id" => id}
    body = %{query: @book_details_query, variables: variables}

    case Req.post(@graphql_endpoint, json: body, headers: @headers) do
      {:ok, %{status: 200, body: %{"data" => %{"book" => book}}}} when not is_nil(book) ->
        {:ok, book}

      {:ok, %{status: 200, body: %{"data" => %{"book" => nil}}}} ->
        {:error, :not_found}

      {:ok, %{status: 200, body: %{"errors" => errors}}} ->
        Logger.error("GraphQL get_book_details error: #{inspect(errors)}")
        {:error, :graphql_error}

      error ->
        Logger.error("GraphQL get_book_details request failed: #{inspect(error)}")
        error
    end
  end
end
