defmodule SqlitexFixtures do
  use ExUnitFixtures.FixtureModule

  deffixture golf_db_url, scope: :module do
    'file::memory:?cache=shared'
  end

  deffixture golf_db(golf_db_url), scope: :module do
    {:ok, db} = Sqlitex.open(golf_db_url)
    TestDatabase.init(db)
    teardown :module, fn ->
      Sqlitex.close(db)
    end
    db
  end

  deffixture golf_db_server(golf_db_url, golf_db) do
    {:ok, conn} = Sqlitex.Server.start_link(golf_db_url, name: :golf)
    teardown fn ->
      Sqlitex.Server.stop(conn)
    end
    conn
  end

  deffixture db do
    {:ok, db} = Sqlitex.open(":memory:")
    teardown fn ->
      Sqlitex.close(db)
    end
    db
  end
end
