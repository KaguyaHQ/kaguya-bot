defmodule Kaguyabot.CommentInvocation do
  use Ecto.Schema

  schema "comment_invocations" do
    field(:comment_id, :string)
    field(:book_id, :binary_id)
    field(:subreddit, :string)
    field(:invoked_by, :string)
    field(:invoked_at, :utc_datetime_usec)
    field(:responded, :boolean)
    field(:note, :string)

    timestamps(type: :utc_datetime_usec)
  end
end
