path = require 'path'
{$, $$$, EditorView, ScrollView} = require 'atom'
_ = require 'underscore-plus'
{File} = require 'pathwatcher'
fs = require 'fs'
{exec} = require 'child_process'

module.exports =
class ApiBlueprintPreviewView extends ScrollView
  atom.deserializers.add(this)

  @deserialize: (state) ->
    new ApiBlueprintPreviewView(state)

  @content: ->
    @div class: 'api-blueprint-preview native-key-bindings', tabindex: -1

  constructor: ({@editorId, filePath}) ->
    super

    if @editorId?
      @resolveEditor(@editorId)
    else
      @file = new File(filePath)
      @handleEvents()

  serialize: ->
    deserializer: 'ApiBlueprintPreviewView'
    filePath: @getPath()
    editorId: @editorId

  destroy: ->
    @unsubscribe()

  resolveEditor: (editorId) ->
    resolve = =>
      @editor = @editorForId(editorId)

      if @editor?
        @trigger 'title-changed' if @editor?
        @handleEvents()
      else
        # The editor this preview was created for has been closed so close
        # this preview since a preview cannot be rendered without an editor
        @parents('.pane').view()?.destroyItem(this)

    if atom.workspace?
      resolve()
    else
      atom.packages.once 'activated', =>
        resolve()
        @renderApiBlueprint()

  editorForId: (editorId) ->
    for editor in atom.workspace.getEditors()
      return editor if editor.id?.toString() is editorId.toString()
    null

  handleEvents: ->
    @subscribe atom.syntax, 'grammar-added grammar-updated', _.debounce((=> @renderApiBlueprint()), 250)
    @subscribe this, 'core:move-up', => @scrollUp()
    @subscribe this, 'core:move-down', => @scrollDown()

    changeHandler = =>
      @renderApiBlueprint()
      pane = atom.workspace.paneForUri(@getUri())
      if pane? and pane isnt atom.workspace.getActivePane()
        pane.activateItem(this)

    if @file?
      @subscribe(@file, 'contents-changed', changeHandler)
    else if @editor?
      @subscribe(@editor.getBuffer(), 'contents-modified', changeHandler)

  renderApiBlueprint: ->
    @showLoading()
    if @file?
      @file.read().then (contents) => @renderApiBlueprintText(contents)
    else if @editor?
      @renderApiBlueprintText(@editor.getText())

  renderApiBlueprintText: (text) ->
    fs.writeFileSync '/tmp/atom.apib', text
    # Env hack... helps find aglio binary
    env =
        PATH: process.env.PATH + ':/usr/local/bin'
    template = "#{path.dirname __dirname}/templates/api-blueprint-preview.jade"
    exec "aglio -i /tmp/atom.apib -t #{template} -o -", {env}, (err, stdout, stderr) =>
      if err
        @showError(err)
      else
        console.log stderr
        @html @resolveImagePaths stdout

  getTitle: ->
    if @file?
      "#{path.basename(@getPath())} Preview"
    else if @editor?
      "#{@editor.getTitle()} Preview"
    else
      "ApiBlueprint Preview"

  getUri: ->
    if @file?
      "api-blueprint-preview://#{@getPath()}"
    else
      "api-blueprint-preview://editor/#{@editorId}"

  getPath: ->
    if @file?
      @file.getPath()
    else if @editor?
      @editor.getPath()

  showError: (result) ->
    failureMessage = result?.message

    @html $$$ ->
      @h2 'Previewing ApiBlueprint Failed'
      @h3 failureMessage if failureMessage?

  showLoading: ->
    @html $$$ ->
      @div class: 'api-blueprint-spinner', 'Loading ApiBlueprint\u2026'

  resolveImagePaths: (html) =>
    html = $(html)
    imgList = html.find("img")

    for imgElement in imgList
      img = $(imgElement)
      src = img.attr('src')
      continue if src.match /^(https?:\/\/)/
      img.attr('src', path.resolve(path.dirname(@getPath()), src))

    html
