# require "./error"

# [is [not]] file
# [is [not]] not file and is executable
# [is [not]] dir
# [is [not]] directory
# [is [not]] executable file
# [is [not]] not executable
# suffix [is [not]] "mp4"
# name [is [not]] ".DS_store"
# [is [not]] .mp4
# [is [not]] video [file]
# [is [not]] media [file]
# age > 10 seconds
# age <= 1 day
# age >= 4 weeks
# age > age(parent)
# age > age(sibling(".jpg"))
# exists file sibling(".jpg")

module Find::Expression::AST
  abstract class Base
    property pos : Int32
    property text : String

    def initialize(@pos, @text)
    end

    def size
      @text.size
    end

    def to_s(io, parens)
      io << "(" if parens
      io << @text
      io << ")" if parens
    end

    def number?
      false
    end

    def value
      @text
    end

    # abstract def self.parse(scan) : self?
  end

  class Atom < Base
    def initialize(@pos, @text)
    end

    def self.parse(scan) : Base?
      Parens.parse(scan) ||
        IsFile.parse(scan) ||
        IsDirectory.parse(scan) ||
        IsExecutable.parse(scan) ||
        IsFileType.parse(scan) ||
        IsEmpty.parse(scan) ||
        SuffixIs.parse(scan) ||
        NameIs.parse(scan)
    end
  end

  class Parens < Base
    property expr : Base

    def initialize(@pos, @text, @expr)
    end

    def to_s(io, parens = false)
      io << '('
      @expr.to_s(io, parens)
      io << ')'
    end

    def self.parse(scan) : Base?
      pos = scan.offset
      if scan.scan(%r{\s*\(})
        if expr = BooleanOr.parse(scan) || BooleanAnd.parse(scan) || Atom.parse(scan)
          if scan.scan(%r{\s*\)})
            self.new pos: pos, text: scan.string[pos...scan.offset], expr: expr
          else
            raise Expression::ParseError.new "expected a )", scanner: scan
          end
        else
          scan.offset = pos
          nil
        end
      else
        nil
      end
    end
  end

  class IsFile < Base
    property negated : Bool

    def initialize(@pos, @text, @negated)
    end

    def to_s(io, parens = false)
      io << '(' if parens
      io << "is"
      io << " not" if @negated
      io << " file"
      io << ')' if parens
    end

    def self.parse(scan) : Base?
      pos = scan.offset
      if scan.scan(%r{\s*\b(?:is\s+)?(not\s+)?file(?=\s|$)}i)
        self.new pos: pos, text: scan[0].strip, negated: scan[1]? ? true : false
      else
        nil
      end
    end
  end

  class IsDirectory < Base
    property negated : Bool

    def initialize(@pos, @text, @negated)
    end

    def to_s(io, parens = false)
      io << '(' if parens
      io << "is"
      io << " not" if @negated
      io << " directory"
      io << ')' if parens
    end

    def self.parse(scan) : Base?
      pos = scan.offset
      if scan.scan(%r{\s*\b(?:is\s+)?(not\s+)?dir(?:ectory)?(?=\s|$)}i)
        self.new pos: pos, text: scan[0].strip, negated: scan[1]? ? true : false
      else
        nil
      end
    end
  end

  class IsExecutable < Base
    property negated : Bool

    def initialize(@pos, @text, @negated)
    end

    def to_s(io, parens = false)
      io << '(' if parens
      io << "is"
      io << " not" if @negated
      io << " executable file"
      io << ')' if parens
    end

    def self.parse(scan) : Base?
      pos = scan.offset
      if scan.scan(%r{\s*\b(?:is\s+)?(not\s+)?executable(?:\s+file)?(?=\s|$)}i)
        self.new pos: pos, text: scan[0].strip, negated: scan[1]? ? true : false
      else
        nil
      end
    end
  end

  class IsFileType < Base
    property type : String
    property negated : Bool

    def initialize(@pos, @text, @type, @negated)
    end

    def to_s(io, parens = false)
      io << '(' if parens
      io << "is "
      io << "not " if @negated
      io << @type.upcase
      io << " file"
      io << ')' if parens
    end

    def self.parse(scan) : Base?
      pos = scan.offset
      if scan.scan(%r{\s*\b(?:is\s+)?(not\s+)?(video|media|audio|text|html|yaml|json)(?:\s+file)?(?=\s|$)}i)
        self.new pos: pos, text: scan[0].strip, type: scan[2].downcase, negated: scan[1]? ? true : false
      else
        nil
      end
    end
  end

  class IsEmpty < Base
    property negated : Bool

    def initialize(@pos, @text, @negated)
    end

    def to_s(io, parens = false)
      io << '(' if parens
      io << "is "
      io << "not " if @negated
      io << "empty"
      io << ')' if parens
    end

    def self.parse(scan) : Base?
      pos = scan.offset
      if scan.scan(%r{\s*\b(?:is\s+)?(not\s+)?empty(?=\s|$)}i)
        self.new pos: pos, text: scan[0].strip, negated: scan[1]? ? true : false
      else
        nil
      end
    end
  end

  class SuffixLiteral < Base
    property suffix : String

    def initialize(@pos, @text, @suffix)
    end

    def to_s(io, parens = false)
      io << '.'
      io << @suffix
    end

    def self.parse(scan) : Base?
      pos = scan.offset
      if scan.scan(%r{\s*\.([A-Z][A-Z0-9]{0,19})(?=\s|$)}i)
        self.new pos: pos, text: scan[0].strip, suffix: scan[1]
      else
        nil
      end
    end
  end

  class SuffixIs < Base
    property suffix : SuffixLiteral
    property negated : Bool

    def initialize(@pos, @text, @suffix, @negated)
    end

    def to_s(io, parens = false)
      io << '(' if parens
      io << "suffix is "
      io << "not " if @negated
      @suffix.to_s(io, parens)
      io << ')' if parens
    end

    def self.parse(scan) : Base?
      pos = scan.offset
      negated = false
      if scan.scan(%r{\s*\bsuffix\s+(?:is\s+)?((?:not\s+)?)}i)
        negated = true if scan[1].size > 0
        if suffix = SuffixLiteral.parse(scan)
          self.new pos: pos, text: scan.string[pos...scan.offset].strip, suffix: suffix, negated: negated
        else
          scan.offset = pos
          nil
        end
      else
        nil
      end
    end
  end

  class NameIs < Base
    property negated : Bool
    property name : StringLiteral

    def initialize(@pos, @text, @negated, @name)
    end

    def to_s(io, parens = false)
      io << '(' if parens
      io << "name is "
      io << "not " if @negated
      @name.to_s(io, parens)
      io << ')' if parens
    end

    def self.parse(scan) : Base?
      pos = scan.offset
      if scan.scan(%r{\s*name\s+is\s+(not\s+)?}i)
        neg = scan[1]? ? true : false
        if name = StringLiteral.parse(scan)
          self.new pos: pos, text: scan.string[pos...scan.offset].strip, negated: neg, name: name
        else
          scan.offset = pos
          nil
        end
      else
        nil
      end
    end
  end

  class Term < Base
    def self.parse(scan) : Base?
      BooleanAnd.parse(scan) || Atom.parse(scan)
    end
  end

  class BooleanOr < Base
    property left : Base
    property right : Base

    def initialize(@pos, @text, @left, @right)
    end

    def to_s(io, parens = false)
      io << '(' if parens
      @left.to_s(io, parens)
      io << " or "
      @right.to_s(io, parens)
      io << ')' if parens
    end

    def self.parse(scan) : Base?
      pos = scan.offset
      if left = Term.parse(scan)
        if scan.scan(%r{\s*(?<=\s)or\s+}i)
          if right = self.parse(scan)
            self.new pos: pos, text: scan.string[pos...scan.offset].strip, left: left, right: right
          else
            raise Expression::ParseError.new "expected a #{self}", scanner: scan
          end
        else
          # scan.offset = pos
          # nil
          left
        end
      end
    end
  end

  class BooleanAnd < Base
    property left : Base
    property right : Base

    def initialize(@pos, @text, @left, @right)
    end

    def to_s(io, parens = false)
      io << '(' if parens
      @left.to_s(io, parens)
      io << " and "
      @right.to_s(io, parens)
      io << ')' if parens
    end

    def self.parse(scan) : Base?
      pos = scan.offset
      if left = Atom.parse(scan)
        if scan.scan(%r{\s*(?<=\s)and\s+}i)
          if right = self.parse(scan)
            self.new pos: pos, text: scan.string[pos...scan.offset].strip, left: left, right: right
          else
            raise Expression::ParseError.new "expected a #{self}", scanner: scan
          end
        else
          left
        end
      end
    end
  end

  # class BooleanAnd < Base
  #   property left : Base
  #   property right : Base

  #   def initialize(@pos, @text, @left, @right)
  #   end

  #   def to_s(io, parens = false)
  #     left.to_s(io, parens)
  #     io << " AND "
  #     right.to_s(io, parens)
  #   end

  #   def self.parse(scan) : Base?
  #     pos = scan.offset
  #     if left = Sum.parse(scan)
  #       if scan.scan(%r{(\s*)(<=|>=|==|!=|<(?!=)|>(?!=))})
  #         operator = scan[2]
  #         if right = Sum.parse(scan)
  #           self.new pos: pos, text: scan.string[pos..scan.offset], left: left, operator: operator, right: right
  #         else
  #           left
  #         end
  #       else
  #         left
  #       end
  #     else
  #       nil
  #     end
  #   end
  # end

  # # class Identifier < Base
  # #   def self.parse(scan) : self?
  # #     if scan.scan(%r{\s*([A-Za-z_][A-Za-z0-9_]*)})
  # #       self.new pos: scan.offset - scan[1].size, text: scan[1]
  # #     else
  # #       nil
  # #     end
  # #   end
  # # end

  class IntegerLiteral < Base
    property value : Int32 = 0

    def initialize(@pos, @text, @value)
    end

    def to_s(io, parens = false)
      @value.to_s(io)
    end

    def number?
      true
    end

    def self.parse(scan) : self?
      if scan.scan(%r{\s*([\-\+]?\d+(?!\.\d))})
        self.new pos: scan.offset - scan[1].size, text: scan[1], value: scan[1].to_i
      else
        nil
      end
    end
  end

  # class FloatLiteral < Base
  #   property value : Float64 = 0

  #   def initialize(@pos, @text, @value)
  #   end

  #   def to_s(io, parens = false)
  #     @value.to_s(io)
  #   end

  #   def number?
  #     true
  #   end

  #   def self.parse(scan) : self?
  #     if scan.scan(%r{\s*([\-\+]?(?:\d+\.\d+|\d+\.(?=\s|\Z)|\.\d+))})
  #       self.new pos: scan.offset - scan[1].size, text: scan[1], value: scan[1].to_f
  #     else
  #       nil
  #     end
  #   end
  # end

  class StringLiteral < Base
    property value : String

    def initialize(@pos, @text, @value)
    end

    def to_s(io, parens = false)
      @value.inspect(io)
    end

    private def self.parse_delimited(scan, pos, delim = "\"")
      end_pattern = Regex.new Regex.escape delim
      literal_char_pattern = Regex.new "[^\\#{delim}]+"
      value = String.build do |str|
        loop do
          if scan.eos?
            raise Expression::ParseError.new "end reached without closing '#{delim}'", scanner: scan
          elsif scan.scan(end_pattern)
            break
          elsif scan.scan(%r{\\r})
            str << '\r'
          elsif scan.scan(%r{\\n})
            str << '\n'
          elsif scan.scan(%r{\\t})
            str << '\t'
          elsif scan.scan(%r{\\x\{([A-Fa-f0-9]+)\}})
            str << scan[1].hexbytes.to_s
          elsif scan.scan(%r{\\x([A-Fa-f0-9]{2})})
            str << scan[1].hexbytes.to_s
          elsif scan.scan(literal_char_pattern)
            str << scan[0]
          else
            raise Expression::ParseError.new "unexpected characters in literal string delimited by #{delim.inspect}", scanner: scan
          end
        end
      end
      self.new pos: pos, text: scan.string[pos..scan.offset], value: value
    end

    def self.parse(scan) : self?
      pos = scan.offset
      if scan.scan(%r{\s*(['"])})
        parse_delimited(scan, pos, scan[1])
      else
        nil
      end
    end
  end

  # class Parens < Base
  #   property expression : Base

  #   def initialize(@pos, @text, @expression)
  #   end

  #   def to_s(io, parens = false)
  #     io << "( "
  #     expression.to_s(io, parens)
  #     io << " )"
  #   end

  #   def self.parse(scan) : self?
  #     offset = scan.offset
  #     if scan.scan(%r{(\s*)(\()})
  #       pos = offset + scan[1].size
  #       if expr = Expr.parse(scan)
  #         if scan.scan(%r{\s*\)})
  #           self.new pos: pos, text: scan.string[pos..scan.offset], expression: expr
  #         else
  #           raise Expression::ParseError.new "expected a closing parenthese", scanner: scan
  #         end
  #       else
  #         raise Expression::ParseError.new "expected a valid expression", scanner: scan
  #       end
  #     else
  #       nil
  #     end
  #   end
  # end

  # class Factor < Base
  #   def self.parse(scan) : Base?
  #     IntegerLiteral.parse(scan) || FloatLiteral.parse(scan) || Identifier.parse(scan) || Parens.parse(scan)
  #   end
  # end

  # class Term < Base
  #   property left : Base
  #   property right : Base
  #   property operator : String

  #   def initialize(@pos, @text, @left, @operator, @right)
  #   end

  #   def to_s(io)
  #     left.to_s(io)
  #     io << " "
  #     io << @operator
  #     io << " "
  #     right.to_s(io)
  #   end

  #   def self.parse(scan) : Base?
  #     pos = scan.offset
  #     if left = Factor.parse(scan)
  #       if scan.scan(%r{(\s*)([\/\*])})
  #         operator = scan[2]
  #         if right = Expr.parse(scan)
  #           self.new pos: pos, text: scan.string[pos..scan.offset], left: left, operator: operator, right: right
  #         else
  #           left
  #         end
  #       else
  #         left
  #       end
  #     else
  #       nil
  #     end
  #   end
  # end

  # class Sum < Base
  #   property left : Base
  #   property right : Base
  #   property operator : String

  #   def initialize(@pos, @text, @left, @operator, @right)
  #   end

  #   def right_is_negative_number?
  #     case r = @right.value
  #     when Int32, Float64
  #       r < 0 ? r.abs : false
  #     else
  #       false
  #     end
  #   end

  #   def to_s(io, parens = false)
  #     io << "( " if parens
  #     left.to_s(io)
  #     io << " "
  #     if r = right_is_negative_number?
  #       if @operator == "+"
  #         io << "- "
  #         r.to_s(io)
  #       elsif @operator == "-"
  #         io << "+ "
  #         r.to_s(io)
  #       else
  #         io << @operator
  #         io << " "
  #         @right.to_s(io)
  #       end
  #     else
  #       io << @operator
  #       io << " "
  #       right.to_s(io)
  #     end
  #     io << " )" if parens
  #   end

  #   def self.parse(scan) : Base?
  #     pos = scan.offset
  #     if left = Term.parse(scan)
  #       if scan.scan(%r{(\s*)([\-\+])})
  #         operator = scan[2]
  #         if right = Sum.parse(scan)
  #           self.new pos: pos, text: scan.string[pos..scan.offset], left: left, operator: operator, right: right
  #         else
  #           left
  #         end
  #       else
  #         left
  #       end
  #     else
  #       nil
  #     end
  #   end
  # end

  # class Expr < Base
  #   property left : Base
  #   property right : Base
  #   property operator : String

  #   def initialize(@pos, @text, @left, @operator, @right)
  #   end

  #   def to_s(io, parens = false)
  #     left.to_s(io, parens)
  #     io << " "
  #     io << @operator
  #     io << " "
  #     right.to_s(io, parens)
  #   end

  #   def self.parse(scan) : Base?
  #     pos = scan.offset
  #     if left = Sum.parse(scan)
  #       if scan.scan(%r{(\s*)(<=|>=|==|!=|<(?!=)|>(?!=))})
  #         operator = scan[2]
  #         if right = Sum.parse(scan)
  #           self.new pos: pos, text: scan.string[pos..scan.offset], left: left, operator: operator, right: right
  #         else
  #           left
  #         end
  #       else
  #         left
  #       end
  #     else
  #       nil
  #     end
  #   end
  # end
end
