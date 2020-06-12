require "../src/picomewku"

source = File.read("examples/lingua.pku")
Picomewku.verbose_exec source
