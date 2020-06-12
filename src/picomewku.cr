
module Picomewku
  VERSION = "0.1.0"

  def self.exec(code_string)
    Parser.new(
      Lexer.new(code_string).lex
    ).execute
  end

  def self.verbose_exec(code_string)
    lexer = Lexer.new code_string
    pp lexer.tokenize.map {|t| t.content}
    pp lexer.lex.map {|t| t.to_s}
    parser = Parser.new(lexer.tokens)
    parser.debug = true
    # pp parser.exec
    parser.build_ast
    parser.print_ast
    parser.execute
  end

  class Token
    property type
    property content
    TYPES = [
      :unparsed_token,
      :word,
      :number,
      :operator,
      :open_block,
      :close_block,
      :open_paren,
      :close_paren,
      :string,
      :newline,
    ]

    def initialize(@type : Symbol = :unparsed_token, @content : String = "")
    end

    def valid_type?
      TYPES.includes? @type
    end

    def to_s
      "[#{type}]<#{content}>"
    end
  end

  class Lexer
    property source_string
    property tokens

    NUMBER_RE = /[0-9]*\.[0-9]+|[0-9]+/
    WORD_RE = /[a-zA-Z0-9_]+/
    OPERATOR_RE = /[\+\-\=\<\>\[\]\:]/

    def initialize(@source_string : String)
      @tokens = [] of Token
    end

    def tokenize
      lines = @source_string.split(/\n/).compact_map do |line|
        next if line.nil? || line[/^#/]?
        line.gsub /#.*/, ""
      end
      puts "lines"
      pp lines
      @tokens = lines.join("\n").scan(/".*"|#{NUMBER_RE}|#{WORD_RE}|#{OPERATOR_RE}|[\;\n\.\(\)]/).each.map do |word|
        Token.new content: word[0]
      end.reject { |t| t.content.nil? || t.content === / +/ }.to_a 
    end

    def self.lex(source_string)
      new(source_string).lex
    end

    def lex
      @tokens.nil? || tokenize

      @tokens.each.with_index do |token, index|
        case token.content
        when /^".*"$/
          token.type = :string
        when /^#{NUMBER_RE}$/
          token.type = :number
        when /^#{WORD_RE}$/
          token.type = :word
        when /^#{OPERATOR_RE}+$/
          token.type = :operator
        when "."
          token.type = :member_operator
        when /\;|\n/
          token.type = :newline
        when "("
          token.type = :open_paren
        when ")"
          token.type = :close_paren
        when "{"
          token.type = :open_block
        when "}"
          token.type = :close_block
        else 
          puts "Warning: uncaught token: #{token.to_s}"
        end
      end
      @tokens
    end
  end

  class Node
    @children = [] of Node
    @value : String | Float64 | Int64 | Nil
    @scope = [] of Node
    @class_name = "Object"
    @name : String?
    @parent : Node?

    property children, token, class_name, scope, value, parent, name

    def initialize(@token : Token? = nil, @value = nil, @name : String? = nil)
    end

    def push_node(node : self)
      node.parent = self
      @children << node
      node
    end

    def value
      @value || @token.try &.content
    end

    def self.root
      self.new.tap {|r| r.build_core_scope}
    end

    def arguments
      in_paren = false
      @children.select do |node|
        if node.token.try &.type == :open_paren
          in_paren = true
          false
        elsif node.token.try &.type == :close_paren
          in_paren = false
          false
        elsif in_paren
          true
        end
      end
    end

    # The default operators and methods
    def build_core_scope
      @scope += [
        StandardType::ExternProc.new(name: "puts") { |nodes|
          nodes.try &.each{|node| print node.try &.value}
          print '\n'
          nil
        },
      ]
    end

    def execute; end
    # PROC execution
    def execute(target : Array(Node) = [self]);end

    # normal evaluation
    def evaluate
      @children.each do |child|
        child.evaluate
      end
    end

    def find_in_scope(name=@name)
      @scope.find {|n| n.name == name} || @parent.try &.find_in_scope(name)
    end

    def exists_in_scope?(name=@name)
      @scope.any? {|n| n.name == name} || @parent.try &.exists_in_scope?(name)
    end

    module StandardType
      class TypeInteger < Node
        def initialize
          super
          @class_name = "Integer"
          @scope += [
            ExternProc.new
          ]
        end
      end

      class TypeString < Node
        def initialize()
          @class_name = "String"  
        end
      end

      class TypeArray < Node
        def initialize()
          @class_name = "Array"
        end

        def set(*args)
          @children = args
          self
        end
      end

      class TypeProc < Node
        def initialize
          super
          @class_name = "Proc"
        end
      end

      # For defining standard methods
      class ExternProc < Node
        def initialize(*args, **kwargs, &block : Proc(Array(Node)?, Node?))
          super(*args, **kwargs)
          @class_name = "ExternProc"
          @method_proc = block
        end

        def execute(target : Array(Node) = [self])
          @method_proc.call(target)
        end
      end

      # Basically a pointer
      class Word < Node
        def initialize(*args, **kwargs)
          super(*args, **kwargs)
          @class_name = "Word"
          raise "No token given" unless @token
          raise "Token type mismatch: Word != #{@token.try &.type || "EMPTY"}\n#{self.inspect}" unless @token.try &.type == :word
          @name = @token.try &.content
        end

        def evaluate
          execute arguments
        end

        # Find defined proc and execute it
        def execute 
          node = find_in_scope
          node.execute @children if node
        end

        def execute(target : Array(Node) = [self])
          node = find_in_scope
          node.execute target if node
        end
      end
    end
  end

  class Parser
    @head : Node
    @ast : Node
    @debug : Bool = false
    @built : Bool = false
    property debug
    def initialize(@tokens : Array(Token))
      @ast = Node.root
      @head = @ast # head "pointer"
    end

    def build_ast
      return if @built
      @head = @ast
      @tokens.each do |token|
        pp @ast.scope if @debug
        puts "ast: #{@ast}" if @debug
        case token.type
        when :word
          #variables,functions and such
          @head = node = @head.push_node Node::StandardType::Word.new token: token
          raise "#{token.content} doesn't exist in scope" unless node.exists_in_scope?
        when :number
          @head.push_node Node.new(token: token)
        when :string
          node = @head.push_node Node.new(token: token)
          node.value = token.content
        when :operator
        when :open_block
          @head.push_node Node.new(token: token)
        when :close_block
          @head.push_node Node.new(token: token)
        when :open_paren
          @head.push_node Node.new(token: token)
        when :close_paren
          @head.push_node Node.new(token: token)
        when :newline
          @head = @head.parent || @ast
        else
          raise "Unhandled token! <#{token.type}>"
        end
      end
      @built = true
    end

    def print_ast(level : Int32 =0, node=@ast)
      puts "#{": "*(level)}#{node.name}|#{node.token.try &.type}|#{node.class}|#{node.value}|#{node.try &.token.try &.content}"
      node.children.each {|n| print_ast level+1, n}
    end

    def run_ast
      @ast.evaluate
    end

    def execute
      build_ast
      run_ast
    end
  end
end