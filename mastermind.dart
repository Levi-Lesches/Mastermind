import "dart:io";
import "dart:math";

import "package:trotter/trotter.dart";

void clearScreen() => print("\x1B[2J\x1B[0;0H");

enum Player {human, computer}

enum Color {red, yellow, green, blue, white, black}

Color stringToColor(String letter) {
	switch (letter) {
		case "R": return Color.red;
		case "Y": return Color.yellow;
		case "G": return Color.green;
		case "B": return Color.blue;
		case "W": return Color.white;
		case "K": return Color.black;
		default: throw "Invalid color: $letter";
	}
}

String colorToString(Color color) {
	switch (color) {
		case Color.red: return "R";
		case Color.yellow: return "Y";
		case Color.green: return "G";
		case Color.blue: return "B";
		case Color.white: return "W";
		case Color.black: return "K";
		default: throw "Invalid color: $color";
	}
}

List<Color> convertStringToColors(String input) => [
	for (final String letter in input.split(", "))
		stringToColor(letter)
];

String colorsToString(List<Color> colors) => [
	for (final Color color in colors)
		colorToString(color)
].join(", ");

enum Response {white, black}

Response stringToResponse(String letter) {
	switch (letter) {
		case "K": return Response.black;
		case "W": return Response.white;
		default: throw "Invalid response: $letter";
	}
}

String responseToString(Response response) {
	switch (response) {
		case Response.white: return "W";
		case Response.black: return "K";
		default: throw "Invalid response: $response";
	}
}

List<Response> convertStringToResponses(String input) => [
	for (final String letter in input.split(", "))
		stringToResponse(letter)
];

String responsesToString(List<Response> responses) => [
	for (final Response response in responses)
		responseToString(response)
].join(", ");

class Attempt {
	final List<Color> code;
	final List<Response> response;

	const Attempt(this.code, this.response);

	@override
	String toString() => "${colorsToString(code)}  |  ${responsesToString(response)}";
}

class Game {
	static final List<Response> correctResponse = List.filled(4, Response.black);

	final Player guesserPlayer, codemakerPlayer;
	final bool debug;

	Guesser guesser;
	Codemaker codemaker;
	List<Attempt> attempts;

	Game({this.guesserPlayer, this.codemakerPlayer, this.debug = false}) {
		attempts = [];
		guesser = Guesser.ofPlayer(this, guesserPlayer);
		codemaker = Codemaker.ofPlayer(this, codemakerPlayer);
	}

	void prettyPrint() {
		clearScreen();
		if (debug) {
			print("$guesser | $codemaker");
		}
		print("\nGame so far: ");
		for (final MapEntry<int, Attempt> attempt in attempts.asMap().entries) {
			print("${attempt.key + 1}: ${attempt.value}");
		}
		print("");
	}

	bool get didGuesserWin => attempts.length <= 10 && 
		attempts.last.response.length == 4 && 
		attempts.last.response.every((Response response) => response == Response.black);

	bool get didCodemakerWin => attempts.length == 10;

	void playTurn() {
		final List<Color> guess = guesser.getGuess();
		final List<Response> response = codemaker.getResponse(guess);
		final Attempt attempt = Attempt(guess, response);
		attempts.add(attempt);
		prettyPrint();
	}
}

abstract class Guesser {
	factory Guesser.ofPlayer(Game game, Player player) {
		switch (player) {
			case Player.human: return PlayerGuesser(game);
			case Player.computer: return ComputerGuesser(game);
			default: throw "Invalid player role: $player";
		}
	}

	final Game game;
	Guesser(this.game);

	List<Color> getGuess();
}

class ComputerGuesser extends Guesser {
	static bool compareResponses(List<Response> a, List<Response> b) {
		final Map<String, Map<Response, int>> counts = {"a": {}, "b": {}};
		for (final Response response in a) {
			counts ["a"] [response] = (counts ["a"] [response] ?? 0) + 1;
		}	
		for (final Response response in b) {
			counts ["b"] [response] = (counts ["b"] [response] ?? 0) + 1;
		}	

		return (
			a.length == b.length &&
			counts ["a"] [Response.white] == counts ["b"] [Response.white] &&
			counts ["a"] [Response.black] == counts ["b"] [Response.black]
		);
	}

	ComputerGuesser(Game game) : super(game);

	List<Color> getGuess() {
		final Permutations<Color> permutations = Permutations(4, Color.values);
		for (final List<Color> possibleCode in permutations()) {
			if (game.attempts.every(
				(Attempt attempt) {
					final List<Response> possibleResponse = ComputerCodemaker.getResponseForCode(possibleCode, attempt.code);
					return compareResponses(possibleResponse, attempt.response);
				}
			)) {
				return possibleCode;
			}
		}
		throw "Could not guess a code. I give up";
	}
}

class PlayerGuesser extends Guesser {
	PlayerGuesser(Game game) : super(game);

	List<Color> getGuess() {
		print("Enter your guess:");
		final String input = stdin.readLineSync();
		return convertStringToColors(input);
	}
}

abstract class Codemaker {
	factory Codemaker.ofPlayer(Game game, Player player) {
		switch(player) {
			case Player.computer: return ComputerCodemaker(game);
			case Player.human: return PlayerCodemaker(game);
			default: throw "Invalid player role: $player";
		}
	}

	final Game game;
	Codemaker(this.game);

	List<Response> getResponse(List<Color> guess);
}

class ComputerCodemaker extends Codemaker {
	static bool canUseColorTwice = false;

	static List<Response> getResponseForCode(List<Color> code, List<Color> guess) {
		final List<Response> result = [];
		for (final MapEntry<int, Color> codeColor in code.asMap().entries) {
			for (final MapEntry<int, Color> guessColor in guess.asMap().entries) {
				if (guessColor.value == codeColor.value) {
					result.add(
						guessColor.key == codeColor.key ? Response.black : Response.white
					);
				}
			}
		}
		return result;
	}

	static List<Color> getRandomCode() {
		final List<Color> result = [];
		final Random random = Random();
		final List<Color> options = List.of(Color.values);
		for (int piece = 0; piece < 4; piece++) {
			final int index = random.nextInt(options.length - 1);
			result.add(options [index]);
			if (!canUseColorTwice) {
				options.removeAt(index);
			}
		}
		return result;
	}

	final List<Color> code;
	ComputerCodemaker(Game game) : 
		code = getRandomCode(),
		super(game); 

	@override
	String toString() => "Computer codemaker ($code)";

	List<Response> getResponse(List<Color> guess) => 
		getResponseForCode(code, guess);
}

class PlayerCodemaker extends Codemaker {
	PlayerCodemaker(Game game) : super(game);

	List<Response> getResponse(List<Color> guess) {
		print("The guesser guessed: ${colorsToString(guess)}");
		print("Enter your response: ");
		return convertStringToResponses(stdin.readLineSync());
	}
}

void main(List<String> args) {
	final Game game = Game(
		guesserPlayer: Player.computer, 
		codemakerPlayer: Player.computer, 
		debug: {"-d", "--debug"}.any(args.contains)
	);

	game.prettyPrint();

	while (true) {
		game.playTurn();
		if (game.didGuesserWin) {
			print("Guesser won!");
			break;
		} else if (game.didCodemakerWin) {
			print("Codemaker won!");
			break;
		} 
	} 
}
