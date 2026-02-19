defmodule Fugue.Repo do
  use Ecto.Repo,
    otp_app: :fugue,
    adapter: Ecto.Adapters.SQLite3
end
