class lp.bootyguard.Main {
    
    private static var s_app:Main;

    public static function main(swfRoot:MovieClip) {
        s_app = new Main(swfRoot);
        
        swfRoot.onLoad = function() { Main.s_app.OnLoad(); };
        swfRoot.onUnload = function() { Main.s_app.OnUnload(); };
    }
    
    public function OnLoad() {
    }

    public function OnUnload() {
    }
    
}