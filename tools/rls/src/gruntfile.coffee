module.exports = (grunt) ->
  grunt.loadNpmTasks('grunt-browserify')
  grunt.loadNpmTasks('grunt-contrib-uglify')
  grunt.loadNpmTasks('grunt-contrib-cssmin')
  grunt.loadNpmTasks('grunt-contrib-watch')
  grunt.loadNpmTasks('grunt-contrib-jade')
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-less')
  grunt.initConfig
    coffee:
      options: bare: true
      compile: files:
        'util.js.tmp': [ 'util.coffee' ]
        'frequency-explorer/main.js.tmp': [ 'frequency-explorer/main.coffee' ]
        'flashcards/main.js.tmp': [ 'flashcards/main.coffee' ]
    browserify: build: files:
      '../frequency-explorer/main.js': [ 'frequency-explorer/main.js.tmp' ]
      '../flashcards/main.js': [ 'flashcards/main.js.tmp' ]
    uglify: build: files:
      '../frequency-explorer/main.min.js': [ '../frequency-explorer/main.js' ]
      '../flashcards/main.min.js': [ '../flashcards/main.js' ]
    less: build: files:
      'common.css.tmp': [ 'common.less' ]
      'frequency-explorer/style.css.tmp': 'frequency-explorer/style.less'
      'flashcards/style.css.tmp': 'flashcards/style.less'
    cssmin: build: files:
      '../frequency-explorer/style.min.css': [ 'frequency-explorer/style.css.tmp' ]
      '../flashcards/style.min.css': [ 'flashcards/style.css.tmp' ]
    jade: compile:
      options: pretty: false
      files:
        '../frequency-explorer/index.html': 'frequency-explorer/index.jade'
        '../flashcards/index.html': 'flashcards/index.jade'
    watch:
      css:
        files: [ '**/*.less' ]
        tasks: [
          'less:build'
          'cssmin:build'
        ]
      coffee:
        files: [ '**/*.coffee' ]
        tasks: [
          'coffee:compile'
          'browserify:build'
          'uglify:build'
        ]
      jade:
        files: [ '*/index.jade' ]
        tasks: [ 'jade:compile' ]
  grunt.registerTask 'build', [
    'coffee:compile'
    'browserify:build'
    'uglify:build'
    'less:build'
    'cssmin:build'
    'jade:compile'
  ]
