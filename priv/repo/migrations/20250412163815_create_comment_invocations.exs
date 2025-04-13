defmodule Kaguyabot.Repo.Migrations.CreateCommentInvocations do
  use Ecto.Migration

  def change do
    create table(:comment_invocations) do
      add :comment_id, :string, null: false
      add :book_id, :uuid
      add :subreddit, :string, null: false
      add :invoked_by, :string, null: false
      add :invoked_at, :utc_datetime_usec, null: false

      add :responded, :boolean, default: false, null: false
      add :note, :string

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:comment_invocations, [:comment_id])
  end
end
