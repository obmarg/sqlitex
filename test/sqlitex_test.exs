defmodule SqlitexTest do
  use ExUnitFixtures
  use ExUnit.Case

  deffixture golf_db_url, do: 'file::memory:?cache=shared'
  deffixture golf_db(golf_db_url), scope: :module do
    {:ok, db} = Sqlitex.open(golf_db_url)
    # TODO: make this use fixtures.
    TestDatabase.init(db)

    on_exit fn ->
      Sqlitex.close(db)
    end

    db
  end

  deffixture golf_db_server(golf_db_url) do
    {:ok, conn} = Sqlitex.Server.start_link(golf_db_url, name: :golf)

    on_exit fn ->
      Sqlitex.Server.stop(conn)
    end

    conn
  end

  deffixture db do
    {:ok, db} = Sqlitex.open(":memory:")
    on_exit fn ->
      Sqlitex.close(db)
    end
    db
  end

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

  @tag fixtures: [:golf_db]
  test "a basic query returns a list of keyword lists", context do
    [row] = context[:golf_db] |> Sqlitex.query("SELECT * FROM players ORDER BY id LIMIT 1")
    assert row == [id: 1, name: "Mikey", created_at: {{2012,10,14},{05,46,28,318107}}, updated_at: {{2013,09,06},{22,29,36,610911}}, type: nil]
  end

  @tag fixtures: [:golf_db]
  test "a basic query returns a list of maps when into: %{} is given", context do
    [row] = context[:golf_db] |> Sqlitex.query("SELECT * FROM players ORDER BY id LIMIT 1", into: %{})
    assert row == %{id: 1, name: "Mikey", created_at: {{2012,10,14},{05,46,28,318107}}, updated_at: {{2013,09,06},{22,29,36,610911}}, type: nil}
  end

  @tag fixtures: [:golf_db_url]
  test "with_db", context do
    [row] = Sqlitex.with_db(context.golf_db_url, fn(db) ->
      Sqlitex.query(db, "SELECT * FROM players ORDER BY id LIMIT 1")
    end)

    assert row == [id: 1, name: "Mikey", created_at: {{2012,10,14},{05,46,28,318107}}, updated_at: {{2013,09,06},{22,29,36,610911}}, type: nil]
  end

  test "table creation works as expected" do
    [row] = Sqlitex.with_db(":memory:", fn(db) ->
      Sqlitex.create_table(db, :users, id: {:integer, [:primary_key, :not_null]}, name: :text)
      Sqlitex.query(db, "SELECT * FROM sqlite_master", into: %{})
    end)

    assert row.type == "table"
    assert row.name == "users"
    assert row.tbl_name == "users"
    assert row.sql == "CREATE TABLE \"users\" (\"id\" integer PRIMARY KEY NOT NULL, \"name\" text )"
  end

  @tag fixtures: [:golf_db]
  test "a parameterized query", context do
    [row] = context[:golf_db] |> Sqlitex.query("SELECT id, name FROM players WHERE name LIKE ?1 AND type == ?2", bind: ["s%", "Team"])
    assert row == [id: 25, name: "Slothstronauts"]
  end

  @tag fixtures: [:golf_db]
  test "a parameterized query into %{}", context do
    [row] = context[:golf_db] |> Sqlitex.query("SELECT id, name FROM players WHERE name LIKE ?1 AND type == ?2", bind: ["s%", "Team"], into: %{})
    assert row == %{id: 25, name: "Slothstronauts"}
  end

  @tag fixtures: [:db]
  test "exec", %{db: db} do
    :ok = Sqlitex.exec(db, "CREATE TABLE t (a INTEGER, b INTEGER, c INTEGER)")
    :ok = Sqlitex.exec(db, "INSERT INTO t VALUES (1, 2, 3)")
    [row] = Sqlitex.query(db, "SELECT * FROM t LIMIT 1")
    assert row == [a: 1, b: 2, c: 3]
    Sqlitex.close(db)
  end

  @tag fixtures: [:db]
  test "it handles queries with no columns", %{db: db} do
    assert [] == Sqlitex.query(db, "CREATE TABLE t (a INTEGER, b INTEGER, c INTEGER)")
    Sqlitex.close(db)
  end

  @tag fixtures: [:db]
  test "it handles different cases of column types", %{db: db} do
    :ok = Sqlitex.exec(db, "CREATE TABLE t (inserted_at DATETIME, updated_at DateTime)")
    :ok = Sqlitex.exec(db, "INSERT INTO t VALUES ('2012-10-14 05:46:28.312941', '2012-10-14 05:46:35.758815')")
    [row] = Sqlitex.query(db, "SELECT inserted_at, updated_at FROM t")
    assert row[:inserted_at] == {{2012, 10, 14}, {5, 46, 28, 312941}}
    assert row[:updated_at] == {{2012, 10, 14}, {5, 46, 35, 758815}}
  end

  @tag fixtures: [:db]
  test "it inserts nil", %{db: db} do
    :ok = Sqlitex.exec(db, "CREATE TABLE t (a INTEGER)")
    [] = Sqlitex.query(db, "INSERT INTO t VALUES (?1)", bind: [nil])
    [row] = Sqlitex.query(db, "SELECT a FROM t")
    assert row[:a] == nil
  end

  @tag fixtures: [:db]
  test "it inserts boolean values", %{db: db} do
    :ok = Sqlitex.exec(db, "CREATE TABLE t (id INTEGER, a BOOLEAN)")
    [] = Sqlitex.query(db, "INSERT INTO t VALUES (?1, ?2)", bind: [1, true])
    [] = Sqlitex.query(db, "INSERT INTO t VALUES (?1, ?2)", bind: [2, false])
    [row1, row2] = Sqlitex.query(db, "SELECT a FROM t ORDER BY id")
    assert row1[:a] == true
    assert row2[:a] == false
  end

  @tag fixtures: [:db]
  test "it inserts Erlang date types", %{db: db} do
    :ok = Sqlitex.exec(db, "CREATE TABLE t (d DATE)")
    [] = Sqlitex.query(db, "INSERT INTO t VALUES (?)", bind: [{1985, 10, 26}])
    [row] = Sqlitex.query(db, "SELECT d FROM t")
    assert row[:d] == {1985, 10, 26}
  end

  @tag fixtures: [:db]
  test "it inserts Elixir time types", %{db: db} do
    :ok = Sqlitex.exec(db, "CREATE TABLE t (t TIME)")
    [] = Sqlitex.query(db, "INSERT INTO t VALUES (?)", bind: [{1, 20, 0, 666}])
    [row] = Sqlitex.query(db, "SELECT t FROM t")
    assert row[:t] == {1, 20, 0, 666}
  end

  @tag fixtures: [:db]
  test "it inserts Erlang datetime tuples", %{db: db} do
    :ok = Sqlitex.exec(db, "CREATE TABLE t (dt DATETIME)")
    [] = Sqlitex.query(db, "INSERT INTO t VALUES (?)", bind: [{{1985, 10, 26}, {1, 20, 0, 666}}])
    [row] = Sqlitex.query(db, "SELECT dt FROM t")
    assert row[:dt] == {{1985, 10, 26}, {1, 20, 0, 666}}
  end

  @tag fixtures: [:db]
  test "query! returns data", %{db: db} do
    :ok = Sqlitex.exec(db, "CREATE TABLE t (num INTEGER)")
    [] = Sqlitex.query(db, "INSERT INTO t VALUES (?)", bind: [1])
    results = Sqlitex.query!(db, "SELECT num from t")
    assert results == [[num: 1]]
  end

  @tag fixtures: [:db]
  test "query! throws on error", %{db: db} do
    :ok = Sqlitex.exec(db, "CREATE TABLE t (num INTEGER)")
    [] = Sqlitex.query(db, "INSERT INTO t VALUES (?)", bind: [1])
    assert_raise Sqlitex.QueryError, "Query failed: {:sqlite_error, 'no such column: nope'}", fn ->
      [_res] = Sqlitex.query!(db, "SELECT nope from t")
    end
  end

  test "server query times out" do
    {:ok, conn} = Sqlitex.Server.start_link(":memory:")
    assert match?({:timeout, _},
      catch_exit(Sqlitex.Server.query(conn, "SELECT * FROM sqlite_master", timeout: 0)))
    receive do # wait for the timed-out message
      msg -> msg
    end
  end

  @tag fixtures: [:db]
  test "decimal types", %{db: db} do
    :ok = Sqlitex.exec(db, "CREATE TABLE t (f DECIMAL)")
    d = Decimal.new(1.123)
    [] = Sqlitex.query(db, "INSERT INTO t VALUES (?)", bind: [d])
    [row] = Sqlitex.query(db, "SELECT f FROM t")
    assert row[:f] == d
  end

  @tag fixtures: [:db]
  test "decimal types with scale and precision", %{db: db} do
    :ok = Sqlitex.exec(db, "CREATE TABLE t (id INTEGER, f DECIMAL(3,2))")
    [] = Sqlitex.query(db, "INSERT INTO t VALUES (?,?)", bind: [1, Decimal.new(1.123)])
    [] = Sqlitex.query(db, "INSERT INTO t VALUES (?,?)", bind: [2, Decimal.new(244.37)])
    [] = Sqlitex.query(db, "INSERT INTO t VALUES (?,?)", bind: [3, Decimal.new(1997)])

    # results should be truncated to the appropriate precision and scale:
    Sqlitex.query(db, "SELECT f FROM t ORDER BY id")
    |> Enum.map(fn row -> row[:f] end)
    |> Enum.zip([Decimal.new(1.12), Decimal.new(244), Decimal.new(1990)])
    |> Enum.each(fn {res, ans} -> assert Decimal.equal?(res, ans) end)
  end
end
