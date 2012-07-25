#!/usr/bin/env ruby

# #############################################################################
# Below are the rules of the TCL Dodekalogue (http://wiki.tcl.tk/10259)
# that should have an effect on the processing of TCL data structures:
# #############################################################################
#
# [3] Words.
#        Words of a command are separated by white space (except for
#        newlines, which are command separators).
#
# [4] Double quotes.
#        If the first character of a word is double quote (“"”) then
#        the word is terminated by the next double quote character.
#        If semicolons, close brackets, or white space characters
#        (including newlines) appear between the quotes then they are
#        treated as ordinary characters and included in the word.
#        Command substitution, variable substitution, and backslash
#        substitution are performed on the characters between the
#        quotes as described below. The double quotes are not retained
#        as part of the word.
#
# [6] Braces.
#        If the first character of a word is an open brace (“{”) and
#        rule [5] does not apply, then the word is terminated by the
#        matching close brace (“}”). Braces nest within the word:
#        for each additional open brace there must be an additional
#        close brace (however, if an open brace or close brace within
#        the word is quoted with a backslash then it is not counted in
#        locating the matching close brace). No substitutions are
#        performed on the characters between the braces except for
#        backslash-newline substitutions described below, nor do
#        semi-colons, newlines, close brackets, or white space receive
#        any special interpretation. The word will consist of
#        exactly the characters between the outer braces, not including
#        the braces themselves.
#
# [9] Backslash substitution.
#        If a backslash (“\”) appears within a word then
#        backslash substitution occurs. In all cases but those
#        described below the backslash is dropped and the following
#        character is treated as an ordinary character and included in
#        the word. This allows characters such as double quotes, close
#        brackets, and dollar signs to be included in words without
#        triggering special processing. The following table lists the
#        backslash sequences that are handled specially, along with
#        the value that replaces each sequence.
#
#    \a   Audible alert (bell) (0x7).
#
#    \b   Backspace (0x8).
#
#    \f   Form feed (0xc).
#
#    \n   Newline (0xa).
#
#    \r   Carriage-return (0xd).
#
#    \t   Tab (0x9).
#
#    \v   Vertical tab (0xb).
#
#    \<newline>whiteSpace
#           A single space character replaces the backslash, newline,
#           and all spaces and tabs after the newline. This
#           backslash sequence is unique in that it is replaced
#           in a separate pre-pass before the command is actually
#           parsed. This means that it will be replaced even when it
#           occurs between braces, and the resulting space will be
#           treated as a word separator if it isn't in braces or
#           quotes.
#
#    \\   Backslash (“\”).
#
#    \ooo  The digits ooo (one, two, or three of them) give an
#            eight-bit octal value for the Unicode character that
#            will be inserted. The upper bits of the Unicode
#            character will be 0.
#
#    \xhh  The hexadecimal digits hh give an eight-bit hexadecimal value
#            for the Unicode character that will be inserted.
#            Any number of hexadecimal digits may be present;
#            however, all but the last two are ignored (the
#            result is always a one-byte quantity). The upper
#            bits of the Unicode character will be 0.
#
#    \uhhhh The hexadecimal digits hhhh (one, two, three, or four of them)
#            give a sixteen-bit hexadecimal value for the
#            Unicode character that will be inserted.
#
#        Backslash substitution is not performed on words enclosed in
#        braces, except for backslash-newline as described above.

module TclDataReader
	def self.move_to_word(f, num_of_words=1)
		num_of_words.times {read_to_next_word f}
	end
	
	def self.read_to_next_word(f)
		c = peek(f)

		if /\s/ =~ c
			read_whitespace f
		else
			read_word f
			read_whitespace f
		end
		
	end

	def self.read_word(f)
		value = nil 

		# read and discard leading whitespace
		read_whitespace f

		begin
			c = f.readchar
		rescue EOFError
			return nil
		end

		if c == "\""
			return read_quotes(f)
		elsif c == "{"
			return read_braces(f)
		else
			# read to the first, unescaped whitespace
			begin
				while /\s/ !~ c do
					if c == "\\"
						c = read_escape f
					end

					if value.nil?
						value = ""
					end

					value << c
					c = f.readchar
				end
			rescue EOFError
				return value
			end
		end

		return value
	end

	def self.read_quotes(f)
		value = ""
		
		c = f.readchar

		while c != "\"" do
			if c == "\\"
				c = read_escape f
			end

			value << c
			c = f.readchar
		end
	
		return value
	end

	def self.read_braces(f)
		value = ""

		brace_count = 1

		while brace_count > 0 do
			c = f.readchar

			if c == "\\"
				next_char = peek(f)

				if next_char == "\n"
					c = read_escape f
				else
					value << (c + next_char)
					f.readchar
				end
			elsif c == "{"
				brace_count += 1
				value << c
			elsif c == "}"
				brace_count -= 1
				if brace_count > 0
					value << c
				end
			else
				value << c
			end
		end

		return value
	end
	
	def self.peek(f, num_chars=1)
		offset = f.tell

		result = f.read num_chars

		f.seek offset

		return result
	end

	def self.read_whitespace(f)
		value = ""

		begin
			next_char = peek(f)

			while /\s/ =~ next_char do
				value << f.readchar
				next_char = peek(f)
			end

			return value
		rescue EOFError
			return value
		end
	end

	def self.read_space_and_tabs(f)
		value = ""

		begin
			next_char = peek(f)

			while next_char == " " || next_char == "\t"
				value << f.readchar
				next_char = peek(f)
			end

			return value
		rescue EOFError
			return value
		end
	end

	def self.read_octals(f)
		result = ""
		begin
			# read at most 2 octal characters
			c1 = peek f
			c2 = peek f

			if /[0-7]/ =~ c1
				# actually read the character
				f.readchar
				result << c1

				if /[0-7]/ =~ c2
					# actually read the other character
					f.readchar

					result << c2
				end
			end
		rescue EOFError
			return result
		end

		return result 
	end

	def self.read_hex(f)
		c1, c2 = nil, nil

		begin
			offset = f.tell
			nextchar = f.readchar
			
			while /[0-9a-fA-F]/ =~ nextchar do
				c1, c2 = c2, nextchar

				offset = f.tell
				nextchar = f.readchar
			end

			# put the next char back
			f.seek offset
			
		rescue EOFError
			if c2.nil?
				return nil
			elsif c1.nil?
				return c2
			else
				return c1+c2
			end
		end

		# did we find any hex digits?
		if c2.nil?
			return nil
		elsif c1.nil?
			return c2
		else
			return c1+c2
		end
	end

	def self.read_unicode(f)
		result = ""
		max = 4

		begin
			offset = f.tell
			c = f.readchar

			while max > 0 && /[0-9a-zA-Z]/ =~ c do
				result << c

				offset = f.tell
				c = f.readchar

				max -= 1
			end
		rescue EOFError
			return result
		end

		return result
	end

	def self.read_escape(f)
		next_char = f.readchar

		case next_char
			when "a"; return 0x7.chr
			when "b"; return 0x8.chr
			when "f"; return 0xc.chr
			when "n"; return 0xa.chr
			when "r"; return 0xd.chr
			when "t"; return 0x9.chr
			when "v"; return 0xb.chr

			when "\n"
				whitespace = read_space_and_tabs f
				return " "

			when "\\"; return "\\"

			when /[0-7]/
				octals = read_octals f
				full_octal = "#{next_char}#{octals}"
				
				# convert to octal
				octal = full_octal.to_i(8)

				# convert to Unicode
				return octal.chr

			when "x"
				hexes = read_hex f
				
				# is this an escaped "x" or a hex char?
				if hexes.nil?
					return "x"
				else
					# convert to hex
					hex = hexes.to_i(16)

					# convert to Unicode
					return hex.chr
				end

			when "u"
				unicodes = read_unicode f
				
				# is this an escaped "u" or a hex char?
				if unicodes.nil?
					return "u"
				else
					return [unicodes.hex].pack("U")
				end

			else
				return next_char
		end
	end
end
