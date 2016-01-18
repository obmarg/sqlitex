defmodule StatementTest do
  use ExUnitFixtures
  use ExUnitFixtures.AutoImport
  use ExUnit.Case, async: true
  doctest Sqlitex.Statement

  @tag fixtures: [:db]
  test "fetch_all! works", %{db: db} do
    result = Sqlitex.Statement.prepare!(db, "PRAGMA user_version;")
             |> Sqlitex.Statement.fetch_all!

    assert result == [[user_version: 0]]
  end
end
