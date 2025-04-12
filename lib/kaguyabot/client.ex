defmodule Kaguyabot.GraphQLClient do
  @moduledoc """
  A minimal client to call the Kaguya GraphQL API.
  """

  # update if needed
  @graphql_endpoint "https://api.kaguya.io/graphql"

  @query """
  query SearchBooks($title: String!, $page: Int!) {
    search_books(title: $title, page: $page) {
      items {
        id
        title
        slug
        ratings_count
        images
        authors
      }
      pagination {
        page
        page_size
        total_pages
        total_count
      }
    }
  }
  """

  def search_books(title) do
    variables = %{"title" => title, "page" => 1}

    body = %{query: @query, variables: variables}
    headers = [{"Content-Type", "application/json"}]

    case Req.post(@graphql_endpoint, json: body, headers: headers) do
      {:ok, %{status: 200, body: response_body}} ->
        {:ok, response_body}

      error ->
        error
    end
  end

  @book_details_query """
  query GetBookMeta($id: ID!) {
    book(id: $id) {
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
    headers = [{"Content-Type", "application/json"}]

    case Req.post(@graphql_endpoint, json: body, headers: headers) do
      {:ok, %{status: 200, body: %{"data" => %{"book" => book}}}} ->
        {:ok, book}

      {:ok, %{status: 200, body: %{"data" => %{"book" => nil}}}} ->
        {:error, :not_found}

      error ->
        error
    end
  end
end
