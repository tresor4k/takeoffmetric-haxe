// TakeoffMetric US construction estimating constants, dataset version 1.2.0.
//
// A port of the Go module github.com/tresor4k/takeoffmetric-go: the same table
// (data/constants.csv), embedded at compile time as typed, read-only records.
// Lookup only: the library computes nothing. Method: https://takeoffmetric.com/methodology/
//
// Estimating values only: confirm with your plans, your supplier and your local
// code before ordering or building.

package takeoffmetric;

import haxe.ds.ReadOnlyArray;

/** The publication a constant was read in. **/
typedef Source = {
	final publisher:String;
	final title:String;
	final url:String;
	/** federal_public_domain, manufacturer_datasheet, trade_association, supplier or other. **/
	final type:String;
}

/**
	One row of the constants table. `value` and `valueSI` are the numbers of the
	row; `valueText` keeps the value as the source prints it.

	When `withheld` is true the publisher does not allow republication: `value`
	and `valueSI` are null, `valueText` is empty, and the value is read at
	`source.url`.
**/
typedef Constant = {
	/** Stable row id, for example "CON-001". **/
	final id:String;
	/** concrete, rebar, aggregates, earthwork, ... **/
	final category:String;
	/** The product or material the value is for. **/
	final materialOrItem:String;
	/** What the value measures. **/
	final quantity:String;
	/** The value in US customary units; null when `withheld`. **/
	final value:Null<Float>;
	/** `value` exactly as written in the table. **/
	final valueText:String;
	/** Unit of `value`. **/
	final unit:String;
	/** SI conversion of `value`; null when `withheld` or when the table leaves it empty. **/
	final valueSI:Null<Float>;
	/** Unit of `valueSI`. **/
	final unitSI:String;
	/** The condition the value applies to (loose, bank, compacted, ...). **/
	final condition:String;
	/** The publication the value was read in. **/
	final source:Source;
	/** Date the source was opened and the value read, "YYYY-MM-DD". **/
	final dateOpened:String;
	/** `dateOpened` at midnight UTC, in seconds since 1970-01-01. **/
	final dateOpenedUnix:Float;
	/** TakeoffMetric calculator pages that use the value. **/
	final usedByToolURL:ReadOnlyArray<String>;
	/** Site source files holding the value (not part of this library). **/
	final engineFile:ReadOnlyArray<String>;
	/** Symbols in those files, one per `engineFile` entry. **/
	final engineSymbol:ReadOnlyArray<String>;
	final notes:String;
	/** True when the publisher does not allow republication of the value. **/
	final withheld:Bool;
	/** Domains of the publishers concerned, set only when `withheld`. **/
	final withheldHosts:ReadOnlyArray<String>;
}

class TakeoffMetric {
	// Declared first: statics are initialised in declaration order.
	static final HEADER = "id,category,material_or_item,quantity,value,unit,value_si,unit_si,condition,source_publisher,"
		+ "source_title,source_url,source_type,date_opened,used_by_tool_url,engine_file,engine_symbol,notes,values_withheld,withheld_hosts";
	static final NUMBER = ~/^-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$/;
	static final DATE = ~/^([0-9]{4})-([0-9]{2})-([0-9]{2})$/;
	static final constantsCSV:String = Embed.constantsCSV();
	static final table:Array<Constant> = load();
	static final index:Map<String, Int> = [for (i in 0...table.length) table[i].id => i];

	/** Every constant, in table order. **/
	public static function all():ReadOnlyArray<Constant> {
		return table;
	}

	/** The constant with the given id, for example "CON-001", or null. **/
	public static function byID(id:String):Null<Constant> {
		final i = index.get(id);
		return i == null ? null : table[i];
	}

	/**
		The constants whose id, category, material, quantity, condition, publisher
		or notes contain every word of `query`, ignoring case. An empty query
		returns nothing.
	**/
	public static function search(query:String):Array<Constant> {
		final words = ~/\s+/g.split(query.toLowerCase()).filter(w -> w != "");
		if (words.length == 0)
			return [];
		return table.filter(c -> {
			final text = [c.id, c.category, c.materialOrItem, c.quantity, c.condition, c.source.publisher, c.notes].join(" ").toLowerCase();
			for (w in words)
				if (text.indexOf(w) < 0)
					return false;
			return true;
		});
	}

	/**
		Each distinct source of the table once, sorted by publisher, then title,
		then URL (byte order, as in the Go module).
	**/
	public static function sources():Array<Source> {
		final seen = new Map<String, Bool>();
		final out:Array<Source> = [];
		for (c in table) {
			final s = c.source;
			final key = [s.publisher, s.title, s.url, s.type].join("\x00");
			if (seen.exists(key))
				continue;
			seen.set(key, true);
			out.push(s);
		}
		out.sort((a, b) -> a.publisher != b.publisher ? compare(a.publisher, b.publisher) : a.title != b.title ? compare(a.title,
			b.title) : compare(a.url, b.url));
		return out;
	}

	/**
		The embedded table as published (UTF-8, comma-separated). Withheld rows
		carry no value in it either. See `Constant` and data/LICENSE for the
		licence of each part.
	**/
	public static function csv():String {
		return constantsCSV;
	}

	static function compare(a:String, b:String):Int {
		return a < b ? -1 : a > b ? 1 : 0;
	}

	// Loading

	static function load():Array<Constant> {
		final rows = parseCSV(constantsCSV);
		if (rows.length == 0 || rows[0].join(",") != HEADER)
			throw "TakeoffMetric: data/constants.csv: unexpected header";
		final out:Array<Constant> = [];
		for (i in 1...rows.length) {
			try {
				out.push(parse(rows[i]));
			} catch (e:String) {
				throw 'TakeoffMetric: data/constants.csv row ${i + 1}: $e';
			}
		}
		return out;
	}

	static function parse(r:Array<String>):Constant {
		if (r.length != 20)
			throw '${r.length} fields, want 20';
		final withheld = switch r[18] {
			case "true":
				// A withheld row must carry no number at all.
				if (r[4] != "" || r[6] != "")
					throw "withheld row has a value";
				true;
			case "false":
				if (r[19] != "")
					throw "withheld_hosts set on a row that is not withheld";
				false;
			case v:
				throw 'values_withheld: "$v", want true or false';
		}
		return {
			id: r[0],
			category: r[1],
			materialOrItem: r[2],
			quantity: r[3],
			value: withheld ? null : number(r[4], "value"),
			valueText: r[4],
			unit: r[5],
			valueSI: r[6] == "" ? null : number(r[6], "value_si"),
			unitSI: r[7],
			condition: r[8],
			source: {
				publisher: r[9],
				title: r[10],
				url: r[11],
				type: r[12]
			},
			dateOpened: r[13],
			dateOpenedUnix: unixDate(r[13]),
			usedByToolURL: splitList(r[14], "; "),
			engineFile: splitList(r[15], "; "),
			engineSymbol: splitList(r[16], "; "),
			notes: r[17],
			withheld: withheld,
			withheldHosts: splitList(r[19], ";")
		};
	}

	static function number(s:String, field:String):Float {
		if (!NUMBER.match(s))
			throw '$field: "$s"';
		return Std.parseFloat(s);
	}

	static function splitList(s:String, separator:String):Array<String> {
		return s == "" ? [] : s.split(separator);
	}

	/** "YYYY-MM-DD" to seconds since 1970-01-01 at midnight UTC (H. Hinnant, days_from_civil). **/
	static function unixDate(s:String):Float {
		if (!DATE.match(s))
			throw 'date_opened: "$s"';
		final y = Std.parseInt(DATE.matched(1)), m = Std.parseInt(DATE.matched(2)), d = Std.parseInt(DATE.matched(3));
		final leap = (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;
		final monthDays = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
		if (m < 1 || m > 12 || d < 1 || d > monthDays[m - 1])
			throw 'date_opened: "$s"';
		final yy = m <= 2 ? y - 1 : y;
		final era = Std.int((yy >= 0 ? yy : yy - 399) / 400);
		final yoe = yy - era * 400;
		final doy = Std.int((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1;
		final doe = yoe * 365 + Std.int(yoe / 4) - Std.int(yoe / 100) + doy;
		return (era * 146097.0 + doe - 719468) * 86400;
	}

	/**
		RFC 4180 records, as encoding/csv reads them: quoted fields with "" for a
		quote, LF or CRLF line ends, blank lines skipped, a bare quote refused.
	**/
	static function parseCSV(s:String):Array<Array<String>> {
		final rows:Array<Array<String>> = [];
		var row:Array<String> = [];
		var i = 0;
		var line = 1;
		final n = s.length;
		function endOfLine(j:Int):Bool
			return s.charAt(j) == "\n" || (s.charAt(j) == "\r" && s.charAt(j + 1) == "\n");
		while (i < n) {
			final buf = new StringBuf();
			if (s.charAt(i) == '"') {
				i++;
				while (true) {
					if (i >= n)
						throw 'line $line: unterminated quoted field';
					final ch = s.charAt(i);
					if (ch == '"') {
						if (s.charAt(i + 1) == '"') {
							buf.add('"');
							i += 2;
							continue;
						}
						i++;
						break;
					}
					if (ch == "\n")
						line++;
					buf.add(ch);
					i++;
				}
				if (i < n && s.charAt(i) != "," && !endOfLine(i))
					throw 'line $line: extraneous character after a quoted field';
			} else {
				final start = i;
				while (i < n && s.charAt(i) != "," && !endOfLine(i)) {
					if (s.charAt(i) == '"')
						throw 'line $line: bare quote in a field';
					i++;
				}
				buf.add(s.substring(start, i));
			}
			row.push(buf.toString());
			if (i >= n)
				break;
			if (s.charAt(i) == ",") {
				i++;
				if (i >= n)
					row.push("");
				continue;
			}
			// End of record.
			i += s.charAt(i) == "\r" ? 2 : 1;
			line++;
			rows.push(row);
			row = [];
			// Blank lines are skipped.
			while (i < n && endOfLine(i)) {
				i += s.charAt(i) == "\r" ? 2 : 1;
				line++;
			}
		}
		if (row.length > 0)
			rows.push(row);
		for (k in 0...rows.length)
			if (rows[k].length != rows[0].length)
				throw 'record ${k + 1}: ${rows[k].length} fields, want ${rows[0].length}';
		return rows;
	}
}
