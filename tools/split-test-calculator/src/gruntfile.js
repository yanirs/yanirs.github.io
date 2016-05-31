module.exports = function (grunt) {
  // Load tasks.
  grunt.loadNpmTasks('grunt-browserify');
  grunt.loadNpmTasks('grunt-contrib-uglify');
  grunt.loadNpmTasks('grunt-contrib-cssmin');
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-contrib-jade');
  grunt.loadNpmTasks('grunt-contrib-coffee');

  grunt.initConfig({
    coffee: {
      options: {
        bare: true
      },
      compile: {
        files: {
          'bayes.js': ['bayes.coffee']
        }
      }
    },
    browserify: {
      build: {
        files: {
          '../bayes.js': ['bayes.js']
        }
      }
    },
    uglify: {
      build: {
        files: {
          '../bayes.min.js': ['../bayes.js']
        }
      }
    },
    cssmin: {
      build: {
        files: {
          '../style.css': ['style.css']
        }
      }
    },
    jade: {
      compile: {
        options: {
          pretty: false
        },
        files: {
          '../index.html': 'index.jade'
        }
      }
    },
    watch: {
      css: {
        files: ['style.css'],
        tasks: ['cssmin:build']
      },
      coffee: {
        files: ['bayes.coffee'],
        tasks: [
          'coffee:compile',
          'browserify:build',
          'uglify:build'
        ]
      },
      jade: {
        files: ['index.jade'],
        tasks: ['jade:compile']
      }
    }
  });

  grunt.registerTask('build', [
    'coffee:compile',
    'browserify:build',
    'uglify:build',
    'cssmin:build',
    'jade:compile'
  ]);
};
