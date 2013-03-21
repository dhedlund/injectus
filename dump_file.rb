#!/usr/bin/env ruby

$LOAD_PATH.push('lib')

require 'bundler'
require 'injectus'

puts Injectus::YarvSequence.load_file(ARGV[0]).disassemble
