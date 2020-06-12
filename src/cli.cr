require "./picomewku"
require "option_parser"

verbose = false

OptionParser.parse do |parser|
  parser.banner = "PicoMewku!"
  parser.on "-v", "Verbose parsing" {verbose = true}
end

if verbose 
  file = File.read(ARGV.first)
  puts "Reading file #{ARGV.first}\n#{file}"
  Picomewku.verbose_exec file
else
  Picomewku.exec File.read(ARGV.first)
end