url = require 'url'

ApiBlueprintPreviewView = null # Defer until used
renderer = null # Defer until used

createApiBlueprintPreviewView = (state) ->
  ApiBlueprintPreviewView ?= require './api-blueprint-preview-view'
  new ApiBlueprintPreviewView(state)

isApiBlueprintPreviewView = (object) ->
  ApiBlueprintPreviewView ?= require './api-blueprint-preview-view'
  object instanceof ApiBlueprintPreviewView

atom.deserializers.add
  name: 'ApiBlueprintPreviewView'
  deserialize: (state) ->
    createApiBlueprintPreviewView(state) if state.constructor is Object

module.exports =
  config:
    liveUpdate:
      type: 'boolean'
      default: true
    openPreviewInSplitPane:
      type: 'boolean'
      default: true
    grammars:
      type: 'array'
      default: [
        'text.html.markdown.source.gfm.apib'
        'source.apib'
        'source.api-blueprint'
        'source.gfm'
        'source.litcoffee'
        'text.html.basic'
        'text.plain'
        'text.plain.null-grammar'
      ]

  activate: ->
    atom.commands.add 'atom-workspace',
      'api-blueprint-preview:toggle': =>
        @toggle()
      'api-blueprint-preview:copy-html': =>
        @copyHtml()
      'api-blueprint-preview:toggle-break-on-single-newline': ->
        keyPath = 'api-blueprint-preview.breakOnSingleNewline'
        atom.config.set(keyPath, !atom.config.get(keyPath))

    previewFile = @previewFile.bind(this)
    atom.commands.add '.tree-view .file .name[data-name$=\\.api-blueprint]', 'api-blueprint-preview:preview-file', previewFile
    atom.commands.add '.tree-view .file .name[data-name$=\\.markdown]', 'api-blueprint-preview:preview-file', previewFile
    atom.commands.add '.tree-view .file .name[data-name$=\\.md]', 'api-blueprint-preview:preview-file', previewFile
    atom.commands.add '.tree-view .file .name[data-name$=\\.mdown]', 'api-blueprint-preview:preview-file', previewFile
    atom.commands.add '.tree-view .file .name[data-name$=\\.mkd]', 'api-blueprint-preview:preview-file', previewFile
    atom.commands.add '.tree-view .file .name[data-name$=\\.mkdown]', 'api-blueprint-preview:preview-file', previewFile
    atom.commands.add '.tree-view .file .name[data-name$=\\.ron]', 'api-blueprint-preview:preview-file', previewFile
    atom.commands.add '.tree-view .file .name[data-name$=\\.txt]', 'api-blueprint-preview:preview-file', previewFile

    atom.workspace.addOpener (uriToOpen) ->
      try
        {protocol, host, pathname} = url.parse(uriToOpen)
      catch error
        return

      return unless protocol is 'api-blueprint-preview:'

      try
        pathname = decodeURI(pathname) if pathname
      catch error
        return

      if host is 'editor'
        createApiBlueprintPreviewView(editorId: pathname.substring(1))
      else
        createApiBlueprintPreviewView(filePath: pathname)

  toggle: ->
    if isApiBlueprintPreviewView(atom.workspace.getActivePaneItem())
      atom.workspace.destroyActivePaneItem()
      return

    editor = atom.workspace.getActiveTextEditor()
    return unless editor?

    grammars = atom.config.get('api-blueprint-preview.grammars') ? []
    return unless editor.getGrammar().scopeName in grammars

    @addPreviewForEditor(editor) unless @removePreviewForEditor(editor)

  uriForEditor: (editor) ->
    "api-blueprint-preview://editor/#{editor.id}"

  removePreviewForEditor: (editor) ->
    uri = @uriForEditor(editor)
    previewPane = atom.workspace.paneForURI(uri)
    if previewPane?
      previewPane.destroyItem(previewPane.itemForURI(uri))
      true
    else
      false

  addPreviewForEditor: (editor) ->
    uri = @uriForEditor(editor)
    previousActivePane = atom.workspace.getActivePane()
    options =
      searchAllPanes: true
    if atom.config.get('api-blueprint-preview.openPreviewInSplitPane')
      options.split = 'right'
    atom.workspace.open(uri, options).done (apiBlueprintPreviewView) ->
      if isApiBlueprintPreviewView(apiBlueprintPreviewView)
        previousActivePane.activate()

  previewFile: ({target}) ->
    filePath = target.dataset.path
    return unless filePath

    for editor in atom.workspace.getTextEditors() when editor.getPath() is filePath
      @addPreviewForEditor(editor)
      return

    atom.workspace.open "api-blueprint-preview://#{encodeURI(filePath)}", searchAllPanes: true

  copyHtml: ->
    editor = atom.workspace.getActiveTextEditor()
    return unless editor?

    renderer ?= require './renderer'
    text = editor.getSelectedText() or editor.getText()
    renderer.toHTML text, editor.getPath(), editor.getGrammar(), (error, html) =>
      if error
        console.warn('Copying ApiBlueprint as HTML failed', error)
      else
        atom.clipboard.write(html)
