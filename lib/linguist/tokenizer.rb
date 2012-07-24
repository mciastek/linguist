module Linguist
  # Generic programming language tokenizer.
  #
  # Tokens are designed for use in the language bayes classifier.
  # It strips any data strings or comments and preserves significant
  # language symbols.
  class Tokenizer
    # Public: Extract tokens from data
    #
    # data - String to tokenize
    #
    # Returns Array of token Strings.
    def self.tokenize(data)
      new.extract_tokens(data)
    end

    SINGLE_LINE_COMMENTS = [
      '//', # C
      '#',  # Ruby
      '%',  # Tex
    ]

    MULTI_LINE_COMMENTS = [
      ['/*', '*/'],    # C
      ['<!--', '-->'], # XML
      ['{-', '-}'],    # Haskell
      ['(*', '*)']     # Coq
    ]

    START_SINGLE_LINE_COMMENT =  Regexp.compile(SINGLE_LINE_COMMENTS.map { |c|
      "^\s*#{Regexp.escape(c)} "
    }.join("|"))

    START_MULTI_LINE_COMMENT =  Regexp.compile(MULTI_LINE_COMMENTS.map { |c|
      Regexp.escape(c[0])
    }.join("|"))

    # Internal: Extract generic tokens from data.
    #
    # data - String to scan.
    #
    # Examples
    #
    #   extract_tokens("printf('Hello')")
    #   # => ['printf', '(', ')']
    #
    # Returns Array of token Strings.
    def extract_tokens(data)
      s = StringScanner.new(data)

      tokens = []
      until s.eos?
        # Single line comment
        if token = s.scan(START_SINGLE_LINE_COMMENT)
          tokens << token.strip
          s.skip_until(/\n|\Z/)

        # Multiline comments
        elsif token = s.scan(START_MULTI_LINE_COMMENT)
          tokens << token
          close_token = MULTI_LINE_COMMENTS.assoc(token)[1]
          s.skip_until(Regexp.compile(Regexp.escape(close_token)))
          tokens << close_token

        # Skip single or double quoted strings
        elsif s.scan(/"/)
          s.skip_until(/[^\\]"/)
        elsif s.scan(/'/)
          s.skip_until(/[^\\]'/)

        # Skip number literals
        elsif s.scan(/(0x)?\d(\d|\.)*/)

        # SGML style brackets
        elsif token = s.scan(/<[^\s<>][^<>]*>/)
          extract_sgml_tokens(token).each { |t| tokens << t }

        # Common programming punctuation
        elsif token = s.scan(/;|\{|\}|\(|\)/)
          tokens << token

        # Regular token
        elsif token = s.scan(/[\w\.@#\/\*]+/)
          tokens << token

        # Common operators
        elsif token = s.scan(/<<?|\+|\-|\*|\/|%|&&?|\|\|?/)
          tokens << token

        else
          s.getch
        end
      end

      tokens
    end

    # Internal: Extract tokens from inside SGML tag.
    #
    # data - SGML tag String.
    #
    # Examples
    #
    #   extract_sgml_tokens("<a href='' class=foo>")
    #   # => ["<a>", "href="]
    #
    # Returns Array of token Strings.
    def extract_sgml_tokens(data)
      s = StringScanner.new(data)

      tokens = []

      until s.eos?
        # Emit start token
        if token = s.scan(/<\/?[^\s>]+/)
          tokens << "#{token}>"

        # Emit attributes with trailing =
        elsif token = s.scan(/\w+=/)
          tokens << token

          # Then skip over attribute value
          if s.scan(/"/)
            s.skip_until(/[^\\]"/)
          elsif s.scan(/'/)
            s.skip_until(/[^\\]'/)
          else
            s.skip_until(/\w+/)
          end

        # Emit lone attributes
        elsif token = s.scan(/\w+/)
          tokens << token

        # Stop at the end of the tag
        elsif s.scan(/>/)
          s.terminate

        else
          s.getch
        end
      end

      tokens
    end
  end
end
