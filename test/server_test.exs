defmodule SqlitexServerTest do
  use ExUnitFixtures
  use ExUnit.Case

  @tag fixtures: [:golf_db_server]
  test "server basic query" do
    [row] = Sqlitex.Server.query(:golf, "SELECT * FROM players ORDER BY id LIMIT 1")
    assert row == [id: 1, name: "Mikey", created_at: {{2012,10,14},{05,46,28,318107}}, updated_at: {{2013,09,06},{22,29,36,610911}}, type: nil]
  end

  @tag fixtures: [:golf_db_server]
  test "server basic query by name" do
    [row] = Sqlitex.Server.query(:golf, "SELECT * FROM players ORDER BY id LIMIT 1")
    assert row == [id: 1, name: "Mikey", created_at: {{2012,10,14},{05,46,28,318107}}, updated_at: {{2013,09,06},{22,29,36,610911}}, type: nil]
  end

  test "that it returns an error for a bad query" do
    {:ok, _} = Sqlitex.Server.start_link(":memory:", name: :bad_create)
    assert {:error, {:sqlite_error, 'near "WHAT": syntax error'}} == Sqlitex.Server.query(:bad_create, "CREATE WHAT")
  end

  test "server query times out" do
    {:ok, conn} = Sqlitex.Server.start_link(":memory:")
    assert match?({:timeout, _},
                  catch_exit(Sqlitex.Server.query(conn, "SELECT * FROM sqlite_master", timeout: 0)))
    receive do # wait for the timed-out message
      msg -> msg
    end
  end

end
