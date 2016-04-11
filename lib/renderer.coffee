{exec} = require 'child_process'
os = require 'os'
path = require 'path'
_ = require 'underscore-plus'
fs = require 'fs-plus'
cheerio = require 'cheerio'
{$} = require 'atom-space-pen-views'

{resourcePath} = atom.getLoadSettings()
packagePath = path.dirname(__dirname)

exports.toDOMFragment = (text='', filePath, grammar, callback) ->
  render text, filePath, (error, html) ->
    return callback(error) if error?

    template = document.createElement('template')
    template.innerHTML = html
    domFragment = template.content.cloneNode(true)

    callback(null, domFragment)

exports.toHTML = (text='', filePath, grammar, callback) ->
  render text, filePath, callback

render = (text, filePath, callback) ->

  # Use current time and random number to generate a temp file name
  #   This way each rendering execution have their own unshared temp file
  #   This avoids error when rendering multiple times in a short period of time.
  tempFile = path.join(os.tmpdir(), 'atom' + (new Date).getTime() + '_' + Math.floor(Math.random() * 9007199254740991) + '.apib')
  fs.writeFileSync tempFile, text

  # Env hack... helps find aglio binary
  newEnv = Object.create(process.env)
  npm_bin = atom.project.getPaths().map (p) -> path.join(p, 'node_modules', '.bin')
  newEnv.PATH = npm_bin.concat(newEnv.PATH, '/usr/local/bin').join(path.delimiter)

  template = "#{path.dirname __dirname}/templates/api-blueprint-preview.jade"

  includePath = path.dirname filePath # for Aglio include directives

  options = {
      maxBuffer: Infinity # Default: 200*1024, set to Infinity to avoid stdout maxBuffer exceeded
      env: newEnv # Use the new environment to help find aglio binary
  }

  exec "aglio -i #{tempFile} -t #{template} -n #{includePath} -o -", options, (err, stdout, stderr) =>
    if err then return callback(err)
    console.log stderr
    fs.removeSync tempFile
    callback null, resolveImagePaths(stdout, filePath)

resolveImagePaths = (html, filePath) ->
  [rootDirectory] = atom.project.relativizePath(filePath)
  o = cheerio.load(html)
  for imgElement in o('img')
    img = o(imgElement)
    if src = img.attr('src')
      continue if src.match(/^(https?|atom):\/\//)
      continue if src.startsWith('data:image/')
      continue if src.startsWith(process.resourcesPath)
      continue if src.startsWith(resourcePath)
      continue if src.startsWith(packagePath)

      if src[0] is '/'
        unless fs.isFileSync(src)
          img.attr('src', path.join(rootDirectory, src.substring(1)))
      else
        img.attr('src', path.resolve(path.dirname(filePath), src))

  o.html()
