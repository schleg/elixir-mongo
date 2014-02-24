defmodule Mongo.Request do
  @moduledoc """
  Defines, encodes and sends MongoDB operations to the server
  """

  defrecordp :request, __MODULE__ ,
    requestID: nil,
    payload: nil

  @update      <<0xd1, 0x07, 0, 0>> # 2001  update document
  @insert      <<0xd2, 0x07, 0, 0>> # 2002  insert new document
  @get_more    <<0xd5, 0x07, 0, 0>> # 2005  Get more data from a query. See Cursors
  @delete      <<0xd6, 0x07, 0, 0>> # 2006  Delete documents
  @kill_cursor <<0xd7, 0x07, 0, 0>> # 2007  Tell database client is done with a cursor

  @query       <<0xd4, 0x07, 0, 0>> # 2004  query a collection
  @query_opts  <<0b00000100::8>>    # default query options, equvalent to `cursor.set_opts(slaveok: true)`

  @doc """
    Builds a query message
  """
  def query(f) do
    request payload: Mongo.Find.query(f)
  end

  @doc """
    Builds a database command message
  """
  def cmd(db, command) do
    request payload:
      @query <> @query_opts <> <<0::24>> <> # [slaveok: true]
      db.name <> ".$cmd" <>
      <<0::40, 255, 255, 255, 255>> <> # skip(0), batchSize(-1)
      document(command)
  end

  @doc """
    Builds an admin command message
  """
  def adminCmd(mongo, command) do
    cmd(mongo.db("admin"), command)
  end

  @doc """
    Builds an insert command message
  """
  def insert(collection, docs) do
    request payload:
      docs |> Enum.reduce(
      @insert <> <<0::32>> <>
      collection.db.name <> "." <>  collection.name <> <<0::8>>,
      fn(doc, acc) -> acc <> Bson.encode(doc) end)
  end

  @doc """
    Builds an update command message
  """
  def update(collection, selector, update, upsert, multi) do
    request payload:
      @update <> <<0::32>> <>
      collection.db.name <> "." <>  collection.name <> <<0::8>> <>
      <<0::6, (bit(multi))::1, (bit(upsert))::1, 0::24>> <>
      (document(selector) ) <>
      (document(update))
  end
  # transforms `true` and `false` to bits
  defp bit(false), do: 0
  defp bit(true), do: 1

  @doc """
    Builds a delete command message
  """
  def delete(collection, selector, justOne) do
    request payload:
      @delete <> <<0::32>> <>
      collection.db.name <> "." <>  collection.name <> <<0::8>> <>
      <<0::7, (bit(justOne))::1, 0::24>> <>
      document(selector)
  end

  @doc """
    Builds a kill_cursor command message
  """
  def kill_cursor(db, cursorid) do
    request payload:
      @kill_cursor <> <<0::32>> <>
      Bson.int32(1) <>
      Bson.int64(cursorid)
  end

  @doc """
    Builds a get_more command message
  """
  def get_more(collection, batchsize, cursorid) do
    request payload:
      @get_more <> <<0::32>> <>
      collection.db.name <> "." <>  collection.name <> <<0::8>> <>
      Bson.int32(batchsize) <>
      Bson.int64(cursorid)
  end

  @doc """
  Sends request to mongodb
  """
  def send(mongo, request(payload: payload, requestID: requestID)) do
    requestID = if requestID==nil, do: gen_reqid, else: requestID
    case message(payload, requestID) |> mongo.send do
      :ok -> requestID
      error -> error
    end
  end

  @doc """
  Sets the request ID

  By default, request ID is generated, but it can be set using this function.
  This is usefull when the connection to MongoDB is active (by default, it is passive)
  """
  def id(requestID, r), do: request(r, requestID: requestID)

  # transform a document into bson
  defp document(nil), do: document({})
  defp document(doc) when is_binary(doc), do: doc
  defp document(doc), do: Bson.encode(doc)

  defp message(payload, reqid) do
    <<(byte_size(payload) + 12)::[size(32),little]>> <> reqid <> <<0::32>> <> <<payload::binary>>
  end
  # generates a request Id when not provided (makes sure it is a positive integer)
  defp gen_reqid() do
    <<tail::24, _::1, head::7>> = :crypto.rand_bytes(4)
    <<tail::24, 0::1, head::7>>
  end


end