module LendingClub
  class Loan < APIResource
    include LendingClub::APIOperations::List
  end
end
