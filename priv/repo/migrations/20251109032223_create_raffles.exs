defmodule Sortio.Repo.Migrations.CreateRaffles do
  use Ecto.Migration

  def change do
    create table(:raffles, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:title, :string, null: false)
      add(:description, :text)
      add(:draw_date, :utc_datetime)
      add(:status, :string, null: false, default: "open")
      add(:creator_id, references(:users, on_delete: :restrict), null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:raffles, [:creator_id]))
    create(index(:raffles, [:status]))

    create(
      constraint(:raffles, :valid_status,
        check: "status IN ('open', 'closed', 'drawing', 'drawn')"
      )
    )
  end
end
