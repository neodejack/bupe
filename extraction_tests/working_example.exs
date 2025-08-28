defmodule Epub do
  def parse_container(xml) do
    import SweetXml

    xml
    |> configure_parse()
    |> xmap(
      rootfile: [~x"//rootfile"l, full_path: ~x"./@full-path", media_type: ~x"./@media-type"]
    )
  end

  def extract_package(archive) do
    {:ok, [{_, container}]} = extract_files(archive, [~c"META-INF/container.xml"])

    %{rootfile: [%{full_path: package_path, media_type: ~c"application/oebps-package+xml"}]} =
      parse_container(container)

    {:ok, [{_, package}]} = extract_files(archive, [package_path])

    parse_package(package)
    |> Map.put(:href, package_path)
  end

  def parse_package(xml) do
    import SweetXml

    xml
    |> configure_parse()
    |> xmap(
      dir: ~x"/package/@dir",
      id: ~x"/package/@id",
      prefix: ~x"/package/@prefix",
      unique_identifier: ~x"/package/@unique-identifier",
      version: ~x"/package/@version",
      metadata: [
        ~x"//metadata",
        identifier: [~x"./dc:identifier"l, id: ~x"./@id", content: ~x"./text()"],
        language: [~x"./dc:language"l, id: ~x"./@id", content: ~x"./text()"],
        title: [~x"./dc:title"l, id: ~x"./@id", content: ~x"./text()"],
        creator: [~x"./dc:creator"l, id: ~x"./@id", content: ~x"./text()"],
        meta: [~x"./meta"l, name: ~x"./@name", content: ~x"./@content"]
      ],
      manifest: [
        ~x"//manifest",
        item: [
          ~x"./item"l,
          href: ~x"./@href",
          id: ~x"./@id",
          media_type: ~x"./@media-type",
          properties: ~x"./@properties"
        ]
      ],
      spine: [
        ~x"//spine",
        toc: ~x"./@toc",
        itemref: [~x"./itemref"l, idref: ~x"./@idref"]
      ]
    )
  end

  def locate_navigation(package) do
    if item =
         Enum.find(package.manifest.item, fn item ->
           item.properties == ~c"nav"
         end) do
      # EPUB 3
      item
    else
      # EPUB 2
      id = package.spine.toc

      Enum.find(package.manifest.item, fn item ->
        item.id == id
      end)
    end
  end

  def extract_navigation(package, archive) do
    item = locate_navigation(package)
    dbg()
    {:ok, [{_, nav}]} = extract_files(archive, [package_relative(package, item.href)])
    dbg()

    case item.media_type do
      ~c"application/x-dtbncx+xml" ->
        parse_ncx(nav)

      ~c"application/xhtml+xml" ->
        parse_nav(nav)
    end
  end

  def parse_ncx(xml) do
    import SweetXml

    xml
    |> configure_parse()
    |> xmap(toc: ~x"//navMap/navPoint"l |> map_by(&parse_ncx_item/1))
  end

  def parse_nav(xml) do
    import SweetXml

    xml
    |> configure_parse()
    |> xmap(toc: ~x"//nav/ol/li"l |> map_by(&parse_nav_item/1))
  end

  def parse_nav_item(doc) do
    import SweetXml

    doc
    |> xmap(
      label: ~x"./a/text()",
      href: ~x"./a/@href",
      children: ~x"./ol/li"l |> map_by(&parse_nav_item/1)
    )
  end

  def parse_ncx_item(doc) do
    import SweetXml

    doc
    |> xmap(
      label: ~x"./navLabel/text/text()",
      href: ~x"./content/@src",
      children: ~x"./navPoint"l |> map_by(&parse_ncx_item/1)
    )
  end

  defp map_by(left, fun) do
    SweetXml.transform_by(left, &Enum.map(&1, fun))
  end

  def extract_files(archive, file_list) when is_list(file_list) do
    :zip.extract(archive, [{:file_list, file_list}, :memory])
  end

  def package_relative(package, href) do
    case Path.dirname(package.href) do
      "." ->
        href

      dir ->
        Path.join(dir, href) |> to_charlist()
    end
  end

  defp configure_parse(xml) do
    xml
    |> SweetXml.parse(
      validation: :off,
      fetch_fun: fn _uri, state ->
        {:ok, :not_fetched, state}
      end
    )
  end
end
