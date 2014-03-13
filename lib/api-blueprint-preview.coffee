url = require 'url'
fs = require 'fs-plus'

ApiBlueprintPreviewView = require './api-blueprint-preview-view'

module.exports =
  configDefaults:
    grammars: [
      'source.apib'
      'source.api-blueprint'
      'source.gfm'
      'source.litcoffee'
      'text.plain'
      'text.plain.null-grammar'
    ]

  activate: ->
    atom.workspaceView.command 'api-blueprint-preview:toggle', =>
      @toggle()

    atom.workspace.registerOpener (uriToOpen) ->
      {protocol, host, pathname} = url.parse(uriToOpen)
      pathname = decodeURI(pathname) if pathname
      return unless protocol is 'api-blueprint-preview:'

      if host is 'editor'
        new ApiBlueprintPreviewView(editorId: pathname.substring(1))
      else
        new ApiBlueprintPreviewView(filePath: pathname)

  toggle: ->
    editor = atom.workspace.getActiveEditor()
    return unless editor?

    grammars = atom.config.get('api-blueprint-preview.grammars') ? []
    return unless editor.getGrammar().scopeName in grammars

    uri = "api-blueprint-preview://editor/#{editor.id}"

    previewPane = atom.workspace.paneForUri(uri)
    if previewPane
      previewPane.destroyItem(previewPane.itemForUri(uri))
      return

    previousActivePane = atom.workspace.getActivePane()
    atom.workspace.open(uri, split: 'right', searchAllPanes: true).done (apiBlueprintPreviewView) ->
      if apiBlueprintPreviewView instanceof ApiBlueprintPreviewView
        apiBlueprintPreviewView.renderApiBlueprint()
        previousActivePane.activate()
