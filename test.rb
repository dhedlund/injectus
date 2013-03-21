#!/usr/bin/env ruby

$LOAD_PATH.push('lib')

require 'injectus'

Injectus.capture do
  require 'bundler'
  Bundler.require(:default)
  puts "$LOADED_FEATURES: #{$LOADED_FEATURES.count}"
end

exit

Injectus.capture do
  Bundler.require(:default)
end

puts 'ok!'
