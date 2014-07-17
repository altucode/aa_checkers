require 'colorize'

def add_coords(c1, c2)
  [c1[0] + c2[0], c1[1] + c2[1]]
end

class Piece
  attr_accessor :color, :position, :board
  def initialize(color, position, direction, board)
    @color = color
    @position = position
    @directions = [direction]
    @board = board
  end

  def move_diffs
    diffs = []
    @directions.each do |dir|
      diffs << [dir, 1]
      diffs << [dir,-1]
    end

    diffs
  end

  def perform_slide(coords)
    return false if @board[coords] ||
                    (@position[0] - coords[0]).abs > 1 ||
                    (@position[1] - coords[1]).abs > 1

    delta = [coords[0] <=> @position[0], coords[1] <=> @position[1]]
    return false if !move_diffs.include?(delta)

    move!(coords)
  end

  def perform_jump(coords)
    return false if !can_jump?(coords)
    @board.remove([(coords[0] + @position[0]) / 2, (coords[1] + @position[1]) / 2])

    move!(coords)
  end

  def move!(coords)
    @board[coords] = self
    @board[@position] = nil
    @position = coords
    promote if @position[0] == 7 || @position[0] == 0

    true
  end

  def can_jump?(coords)
    return false if @board[coords]
    from_start = @position.dup
    from_mid = [(coords[0] + @position[0]) / 2, (coords[1] + @position[1]) / 2]
    return false if @board[from_mid].nil? || @board[from_mid].color == @color
    #enables kings to 'super jump'
    return false if (from_mid[0] - from_start[0]).abs > 1 &&
                    @directions.length < 2
    delta = [coords[0] <=> @position[0], coords[1] <=> @position[1]]
    return false if !move_diffs.include?(delta)
    from_start = add_coords(from_start, delta)
    from_mid = add_coords(from_mid, delta)
    until from_mid == coords
      return false if @board[from_start] || @board[from_mid]
      from_start = add_coords(from_start, delta)
      from_mid = add_coords(from_mid, delta)
    end

    true
  end

  def valid_moves?(moves)
    begin
      @board.dup[@position].perform_moves!(moves)
    rescue InvalidMoveError => error
      return false
    end
    true
  end

  def perform_moves!(moves)
    if moves.length > 1 || !perform_slide(moves[0])
      moves.each do |move|
        raise InvalidMoveError.new if !perform_jump(move)
      end
    end
  end

  def perform_moves(moves)
    raise InvalidMoveError.new if !valid_moves?(moves)
    perform_moves!(moves)
  end

  def promote
    @directions << 0 - @directions[0] if @directions.length < 2
  end

  def symbol
    color = @color == :black ? :light_black : :light_red
    @directions.length > 1 ? '✪'.colorize(color) : '◉'.colorize(color)
  end
end

class InvalidMoveError < StandardError
  def initialize
  end
end

class Board
  def initialize(empty = false)
    @grid = Array.new(8) { Array.new(8) }
    return if empty
    x, y = 0, 1
    while x < 8
      @grid[y][x] = Piece.new(:black, [y, x], 1, self)
      @grid[7 - y][7 - x] = Piece.new(:red, [7 - y, 7 - x], -1, self)
      if (y += 2) > 2
        y %= 3
        x += 1
      end
    end
  end

  def remove(coords)
    self[coords] = nil if self[coords]
  end

  def [](coords)
    return @grid[coords[0]][coords[1]] if coords.all? { |n| n.between?(0, 7) }
  end

  def []=(coords, val)
    @grid[coords[0]][coords[1]] = val if coords.all? { |n| n.between?(0, 7) }
  end

  def dup
    new_board = Board.new(true)
    @grid.flatten.compact.each do |piece|
      new_board[piece.position] = piece.dup
      new_board[piece.position].board = new_board
    end
    new_board
  end

  def over?
    @grid.flatten.compact.all? { |piece| piece.color == :black } ||
    @grid.flatten.compact.all? { |piece| piece.color == :red }
  end

  def display(select = nil)
    system 'clear'
    puts "+ ABCDEFGH".colorize(:light_white).on_black
    i = 0
    bg = :black
    @grid.each do |row|
      print "#{i += 1}".colorize(:light_white).on_black + ' '
      row.each do |piece|
        bg = bg == :black ? :red : :black
        str = ''
        if piece
          str = select && piece == select ? piece.symbol.blink : piece.symbol
        else
          str << ' '
        end
        print str.colorize(:background => bg)
      end
      bg = bg == :black ? :red : :black
      puts
    end
  end
end

class Game
  def initialize(player1, player2)
    @board = Board.new
    @players = { :red => player1, :black => player2 }
  end

  def play
    color = :black
    until @board.over?
      color = color == :black ? :red : :black
      begin
        @board.display
        puts "#{color.to_s.capitalize}'s turn."
        selected = @board[@players[color].get_selection]
        raise "No piece selected" if selected.nil?
        raise "Cannot select opponent's piece" if selected.color != color
        @board.display(selected)
        moves = @players[color].get_moves
        selected.perform_moves(moves)
      rescue StandardError => error
        puts error.message
        gets
        retry
      end
    end
    puts "Winner: #{color.to_s.capitalize}"
  end
end

class HumanPlayer
  def initialize
  end

  def parse_coords(input)
    coords = []
    coords << Integer(input[1]) - 1
    coords << ('a'..'h').to_a.find_index(input[0].downcase)
  end

  def get_selection
    begin
      puts "Select a piece to move"
      input = gets.chomp
      raise "Invalid selection" if input.length != 2
      parse_coords(input)
    rescue StandardError => error
      puts error.message
      retry
    end
  end

  def get_moves
    begin
      puts "Enter a sequence of moves to make"
      input = gets.chomp.split(' ')
      raise "Invalid sequence" if input.any? { |str| str.length != 2 }
      moves = []
      input.each { |str| moves << parse_coords(str) }
      moves
    rescue
      retry
    end
  end
end

Game.new(HumanPlayer.new, HumanPlayer.new).play