package takeoffmetric;

#if macro
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/** Embeds data/constants.csv in the compiled program as a string constant (no -resource flag needed). **/
class Embed {
	public static macro function constantsCSV():ExprOf<String> {
		final here = Path.directory(sys.FileSystem.absolutePath(Context.getPosInfos(Context.currentPos()).file));
		final file = Path.normalize(Path.join([here, "..", "..", "data", "constants.csv"]));
		Context.registerModuleDependency("takeoffmetric.TakeoffMetric", file);
		return macro $v{sys.io.File.getContent(file)};
	}
}
