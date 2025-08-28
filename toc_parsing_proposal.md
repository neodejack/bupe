## current behavior
result.nav is the package/spine part of `content.opf`
result.toc is the `media-type="application/x-dtbncx+xml"` part of `content.opf`


## expected behavior
- store toc related information in `config.toc`

- remove the current toc parsing in `parse_xml(config, xml, :manifest)` function. deleting this line @/Users/zilizhang/code/bupe/lib/bupe/parser.ex:152

- change the :navigation parse_xml function

```elixir
defp parse_xml(config, xml, :navigation) do
```

- the logic would be

1. check version of epub

2. if version 2, find toc using the logic
## epub version 2 toc logic
according to [official spec](https://idpf.org/epub/20/spec/OPF_2.0_final_spec.html#Section2.4)
> The spine element must include the toc attribute, whose value is the the id attribute value of the required NCX document declared in manifest (see Section 2.4.1.) 

1. we parse out spine's attribute toc
2. from there we find item in manifest with that id
3. from there we find the actual toc.ncx file
4. we parse the toc.ncx file

3. if version 3, find toc using the logic @/Users/zilizhang/code/bupe/notes_on_navigation_parsing.md:15
## epub version 3 toc logic

according to https://www.w3.org/TR/epub-33/#sec-nav-prop
> The nav property indicates that the described publication resource constitutes the EPUB navigation document of the EPUB publication.
> EPUB creators MUST declare exactly one item as the EPUB navigation document using the nav property.

1. we need to find the item in manifest with property attribute containing the token `nav`. There must be exactly one such item; its href is the path to the Navigation Document. The media type will be XHTML.
