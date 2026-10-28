// vectors.json is written by the Go module github.com/tresor4k/takeoffmetric-go
// (every row through ByID, the output of Search for a few queries, Sources).
// The tests compare the whole Haxe table to it; no value is typed by hand.
// Run from the repository root: haxe test.hxml

import haxe.ds.ReadOnlyArray;
import takeoffmetric.TakeoffMetric;

class Test {
	static var checks = 0;
	static var failures = 0;

	static function eq(got:Dynamic, want:Dynamic, what:String) {
		checks++;
		if (got != want) {
			failures++;
			Sys.println('FAIL $what: got $got, want $want');
		}
	}

	static function ok(cond:Bool, what:String) {
		eq(cond, true, what);
	}

	static function eqList(got:ReadOnlyArray<String>, want:Array<String>, what:String) {
		eq(got.length, want.length, '$what length');
		eq(got.join("\n"), want.join("\n"), what);
	}

	static function eqSource(got:Source, want:Dynamic, what:String) {
		eq(got.publisher, want.publisher, '$what publisher');
		eq(got.title, want.title, '$what title');
		eq(got.url, want.url, '$what url');
		eq(got.type, want.type, '$what type');
	}

	static function num(x:Dynamic):Null<Float> {
		return x == null ? null : (x : Float);
	}

	static function main() {
		final v:Dynamic = haxe.Json.parse(sys.io.File.getContent("test/vectors.json"));
		final all = TakeoffMetric.all();

		// Counts.
		eq(v.dataset_version, "1.2.0", "dataset_version");
		eq(all.length, v.count, "count");
		eq((v.constants : Array<Dynamic>).length, v.count, "vector count");
		eq(all.filter(c -> c.withheld).length, v.withheld_count, "withheld count");

		// Every row matches Go.
		final want:Array<Dynamic> = v.constants;
		eqList([for (c in all) c.id], [for (w in want) w.id], "table order");
		for (w in want) {
			final id:String = w.id;
			final c = TakeoffMetric.byID(id);
			if (c == null) {
				eq(null, id, '$id: byID returned null');
				continue;
			}
			eq(c.id, id, id);
			eq(c.category, w.category, '$id category');
			eq(c.materialOrItem, w.material_or_item, '$id material_or_item');
			eq(c.quantity, w.quantity, '$id quantity');
			eq(c.value, num(w.value), '$id value');
			eq(c.valueText, w.value_text, '$id value_text');
			eq(c.unit, w.unit, '$id unit');
			eq(c.valueSI, num(w.value_si), '$id value_si');
			eq(c.unitSI, w.unit_si, '$id unit_si');
			eq(c.condition, w.condition, '$id condition');
			eqSource(c.source, w.source, '$id source');
			eq(c.dateOpened, w.date_opened, '$id date_opened');
			eq(c.dateOpenedUnix, num(w.date_opened_unix), '$id date_opened_unix');
			eqList(c.usedByToolURL, w.used_by_tool_url, '$id used_by_tool_url');
			eqList(c.engineFile, w.engine_file, '$id engine_file');
			eqList(c.engineSymbol, w.engine_symbol, '$id engine_symbol');
			eq(c.notes, w.notes, '$id notes');
			eq(c.withheld, w.withheld, '$id withheld');
			eqList(c.withheldHosts, w.withheld_hosts, '$id withheld_hosts');
		}

		// Withheld rows carry no number.
		for (c in all) {
			if (c.withheld) {
				ok(c.value == null && c.valueSI == null && c.valueText == "", '${c.id} withheld without value');
				ok(c.withheldHosts.length > 0 && c.source.url != "", '${c.id} withheld hosts and url');
			} else
				ok(c.value != null && c.withheldHosts.length == 0, '${c.id} value present');
		}

		// Search matches Go.
		final searches:Array<Dynamic> = v.searches;
		ok(searches.filter(s -> (s.ids : Array<String>).length > 0).length >= 5, "at least 5 non-empty searches");
		for (s in searches)
			eqList([for (c in TakeoffMetric.search(s.query)) c.id], s.ids, 'search "${s.query}"');

		// Sources match Go.
		final got = TakeoffMetric.sources();
		final wantSources:Array<Dynamic> = v.sources;
		eq(got.length, wantSources.length, "sources length");
		for (i in 0...Std.int(Math.min(got.length, wantSources.length)))
			eqSource(got[i], wantSources[i], 'source $i');

		// Unknown id.
		ok(TakeoffMetric.byID("XXX-000") == null, "unknown id");
		ok(TakeoffMetric.byID("") == null, "empty id");

		// The embedded CSV is the data file.
		eq(TakeoffMetric.csv(), sys.io.File.getContent("data/constants.csv"), "embedded csv");

		Sys.println('$checks checks, $failures failures');
		Sys.exit(failures == 0 ? 0 : 1);
	}
}
