# Renzhi Child Development Lab Website

Static website for the Renzhi Child Development Lab.

## Publish

The site is served directly from the repository root with GitHub Pages. Open
`index.html` for local preview or serve the repository directory with any static
HTTP server.

## Lab News

Lab news entries live in `updates/01-drafts`. After editing an entry, regenerate
`updates/03-data/news-data.js` with:

```powershell
powershell -ExecutionPolicy Bypass -File .\updates\04-tools\update-news.ps1
```

Each entry uses a `YYYY.MM.DD` publish date. The homepage "Latest News" section
and the full "Lab News" page both read from the generated data file.
