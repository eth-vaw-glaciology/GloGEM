# Configuration file for the Sphinx documentation builder.

# -- Project information

project = 'GloGEM'
copyright = '2015-2026, ETH Zurich - Laboratory of Hydraulics, Hydrology and Glaciology (VAW)'
author = 'ETH Zurich - Laboratory of Hydraulics, Hydrology and Glaciology (VAW)'

release = '1.0'
version = '1.0.0'

# -- General configuration

extensions = [
    'sphinx.ext.duration',
    'sphinx.ext.doctest',
    'sphinx.ext.autodoc',
    'sphinx.ext.autosummary',
    'sphinx.ext.intersphinx',
    'sphinx.ext.mathjax',
    'myst_parser',
    'sphinx_copybutton',
]

myst_enable_extensions = [
    "amsmath",  # Enables LaTeX math support
    "dollarmath",  # Enables $...$ and $$...$$ syntax
]

mathjax_path = "https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"

intersphinx_mapping = {
    'python': ('https://docs.python.org/3/', None),
    'sphinx': ('https://www.sphinx-doc.org/en/master/', None),
}
intersphinx_disabled_domains = ['std']

templates_path = ['_templates'] # Add templates path in order to use custom templates for the HTML output

# -- Options for HTML output

html_theme = 'sphinx_book_theme' # Set the HTML theme to use

#html_logo = 'images/GloGEM_logo_v2.png' # Path to the logo image

html_theme_options = {
    "repository_url": "https://github.com/eth-vaw-glaciology/GloGEM",
    "path_to_docs": "docs/source",
    "use_repository_button": True,
    "logo": {
        "image_light": "images/GloGEM_logo_v2.png",
        "image_dark": "images/GloGEM_logo_v3_dark.png",
    }
}

# Set the Pygments style
pygments_style = 'monokai' # Set the Pygments syntax highlighting style

# -- Options for EPUB output
epub_show_urls = 'footnote'

# Set the master doc to index.md
master_doc = 'index'
