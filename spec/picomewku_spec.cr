require "./spec_helper"

describe Picomewku do
  test_file = File.read("examples/lingua.pku")
  describe "lexer" do
    it "tokenizes example without error" do
      lexer = Picomewku::Lexer.new test_file
      lexer.tokenize
      lexer.lex
    end

    it "tokenizes assignment" do
      assignment = Picomewku::Lexer.lex("var_name = 3")
      assignment[0].type.should eq :word
      assignment[1].type.should eq :operator
      assignment[2].type.should eq :number

      assignment = Picomewku::Lexer.lex("var_name = 3.123")
      assignment[0].type.should eq :word
      assignment[1].type.should eq :operator
      assignment[2].type.should eq :number

      assignment = Picomewku::Lexer.lex("var_name = \"meow\"")
      assignment[0].type.should eq :word
      assignment[1].type.should eq :operator
      assignment[2].type.should eq :string
    end

    it "tokenizes functions" do
      tokens = Picomewku::Lexer.lex <<-CODE
        mew_function -> mew {
          return mew
        }
      CODE
    end
  end
end
