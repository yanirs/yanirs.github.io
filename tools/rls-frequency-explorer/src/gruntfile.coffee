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
      compile: files: 'main.js.tmp': [ 'main.coffee' ]
    browserify: build: files: '../main.js': [ 'main.js.tmp' ]
    uglify: build: files: '../main.min.js': [ '../main.js' ]
    less: build: files: 'style.css.tmp': 'style.less'
    cssmin: build: files: '../style.min.css': [ 'style.css.tmp' ]
    jade: compile:
      options: pretty: false
      files: '../index.html': 'index.jade'
    watch:
      css:
        files: [ 'style.less' ]
        tasks: [
          'sass:dist'
          'cssmin:build'
        ]
      coffee:
        files: [ 'main.coffee' ]
        tasks: [
          'coffee:compile'
          'browserify:build'
          'uglify:build'
        ]
      jade:
        files: [ 'index.jade' ]
        tasks: [ 'jade:compile' ]
  grunt.registerTask 'build', [
    'coffee:compile'
    'browserify:build'
    'uglify:build'
    'less:build'
    'cssmin:build'
    'jade:compile'
  ]
