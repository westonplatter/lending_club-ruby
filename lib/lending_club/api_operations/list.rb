module LendingClub
  module APIOperations
    module List
      module ClassMethods
        def all(filters={}, api_key=nil)
          response, api_key = LendingClub.request(:get, url, api_key, filters)

          byebug
          puts response


          Util.convert_to_lending_club_object(response, api_key)
        end
      end

      def self.included(base)
        base.extend(ClassMethods)
      end
    end
  end
end
