defmodule ExtractEpub do

  def run(path) do
    case File.dir?(path) do
      false ->
        path = path |> Path.expand() |> String.to_charlist()

        with :ok <- check_file(path),
             :ok <- check_extension(path) do
          extract(path)
        end
      true ->
        path
          |> File.ls!()
          |> Stream.map(&Path.join(path,&1))
          |> Enum.each(&run/1)
    end
  end




  defp extract(archive) do
    case :zip.extract(archive, [:memory]) do
      {:ok, files_bin} -> 
        save(archive, files_bin)
        {:error, reason} -> 
        IO.puts(reason)
    end
  end

  defp save(archive, files_bin) do
    book_name =
      archive
      |> to_string()
      |> Path.basename(".epub")
    files_bin
    |> Enum.map(&path_to_out_dir(book_name, &1))
    |> Enum.each(&write_to_disk/1)

  end

  defp write_to_disk({path, bin}) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, bin)
  end

  defp path_to_out_dir(book_name, {path, bin}) do
    path = to_string(path)

    {Path.join(["extraction_tests/out", book_name, path]), bin}
  end


  defp check_file(epub) do
    if File.exists?(epub) do
      :ok
    else
      raise ArgumentError, "file #{epub} does not exists"
    end
  end

  defp check_extension(epub) do
    if epub |> Path.extname() |> String.downcase() == ".epub" do
      :ok
    else
      raise ArgumentError, "file #{epub} does not have an '.epub' extension"
    end
  end
  
end
