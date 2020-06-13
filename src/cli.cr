require "./picomewku"
require "option_parser"

verbose = false
exec = true

OptionParser.parse do |parser|
  parser.banner = "PicoMewku!"
  parser.on "-v", "Verbose parsing" { verbose = true }
  parser.on "--tokenize-only", "only tokenize" { 
    pp Picomewku::Lexer.new(File.read(ARGV.first)).tokenize.map {|t| t.content}
    exec = false
  }
end

if verbose && exec
  file = File.read(ARGV.first)
  puts "Reading file #{ARGV.first}\n#{file}"
  Picomewku.verbose_exec file
elsif exec
  Picomewku.exec File.read(ARGV.first)
end