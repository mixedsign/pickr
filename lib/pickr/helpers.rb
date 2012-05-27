module Pickr
  module Helpers
    def possessive(string)
      if string =~ /[sz]$/i
        "#{string}'"
      else
        "#{string}'s"
      end
    end
  end
end
