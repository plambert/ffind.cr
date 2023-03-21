require "string_scanner"
require "./expression/ast"

module Find::Expression
  class ParseError < Exception
    property scanner : StringScanner?

    def initialize(@message, @scanner = nil)
      @message = "#{@message} at #{@scanner.inspect}"
    end
  end

  class Parser
    property text : String
    property scan : StringScanner

    def initialize(@text)
      @scan = StringScanner.new @text
    end

    def parse
      Find::Expression::AST::BooleanOr.parse(@scan)
    end
  end
end
