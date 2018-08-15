# config/initializers/_extensions.rb
#
# Extensions to classes that need to be established as soon as possible during
# initialization.

require(Rails.root.join('lib/ext')) and console_output('Initializing...')
