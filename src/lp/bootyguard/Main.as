import com.GameInterface.DialogIF;
import com.GameInterface.DistributedValue;
import com.GameInterface.Game.CharacterBase;
import mx.utils.Delegate;
import com.Utils.ID32;
import com.GameInterface.UtilsBase;
import com.GameInterface.Nametags;
import com.GameInterface.Game.Dynel;
import com.GameInterface.Game.Character;
import com.Utils.LDBFormat;
import com.Utils.Format;

class lp.bootyguard.Main {

    private static var s_app:Main;

    private static var NYR_PLAYFIELD_ID = 5710;
    private static var NYR_E10_PLAYFIELD_ID = 5715;
    private static var NYR_SLOCK = 7961764;
    private static var NYR_ELITE_LOCK = 9125207;

    public static var LURKER_MAX_HP_17 = 77213848;
    public static var LURKER_MAX_HP_10 = 43199824;
    public static var LURKER_MAX_HP_5 = 10905556;
    public static var LURKER_MAX_HP_1 = 3262582;
    public static var LURKER_MAX_HP_SM = 3262582;

    public static var LURKER_NAME:String = LDBFormat.LDBGetText(51000, 32030);

    private var autoLootInjectInterval:Number;
    private var autoLootInstance:Object;
    private var autoLootArgs:Array;

    private var currentElite = 0;

    public static function main(swfRoot:MovieClip) {
        s_app = new Main(swfRoot);

        swfRoot.onLoad = function() {
            Main.s_app.OnLoad();
        };
        swfRoot.onUnload = function() {
            Main.s_app.OnUnload();
        };
    }

    public function OnLoad() {
        CharacterBase.SignalClientCharacterOfferedLootBox.Connect(SlotClientCharacterOfferedLootBox, this);

        Nametags.SignalNametagAdded.Connect(DynelAdded, this);
        Nametags.SignalNametagRemoved.Connect(DynelAdded, this);
        Nametags.SignalNametagUpdated.Connect(DynelAdded, this);
        Nametags.RefreshNametags();

        autoLootInjectInterval = setInterval(Delegate.create(this, AutoLootInject), 1000);
    }

    public function OnUnload() {
        clearInterval(autoLootInjectInterval);

        Nametags.SignalNametagAdded.Disconnect(DynelAdded, this);
        Nametags.SignalNametagRemoved.Disconnect(DynelAdded, this);
        Nametags.SignalNametagUpdated.Disconnect(DynelAdded, this);

        CharacterBase.SignalClientCharacterOfferedLootBox.Disconnect(SlotClientCharacterOfferedLootBox, this);
    }

    public function SlotClientCharacterOfferedLootBox() {
        if (shouldAskQuestion()) {
            Question();
        } else {
            Continue();
        }
    }

    public function Question() {
        UtilsBase.PrintChatText("Ask the question!");
        var message = Format.Printf("You are about to open an E%d box.\nAre you sure you want to do this?", currentElite);
        var dialogIF = new DialogIF(message, _global.Enums.StandardButtons.e_ButtonsYesNo);
        dialogIF.SignalSelectedAS.Connect(Answer, this);
        dialogIF.Go();
    }

    public function Answer(buttonId:Number) {
        if (buttonId == _global.Enums.StandardButtonID.e_ButtonIDNo) {
            UtilsBase.PrintChatText("The answer is no.");
            DistributedValue.SetDValue("lootBox_window", false);
        } else {
            UtilsBase.PrintChatText("The answer is yes.");
            Continue();
        }
        autoLootInstance = undefined;
    }

    public function Continue() {
        if (autoLootInstance) {
            UtilsBase.PrintChatText("Autoloot detected, so let's call it.");
            var proto = getAutoLootProto();
            if (proto.OpenBox.orig) {
                UtilsBase.PrintChatText("Calling autoloot.");
                proto.OpenBox.orig.apply(autoLootInstance, autoLootArgs);
            } else {
                UtilsBase.PrintChatText("Failed to call autoloot. Reapplying hook...");
                AutoLootInject();
            }
        } else {
            UtilsBase.PrintChatText("No autoloot found, let the user continue.");
        }
        autoLootInstance = undefined;
    }

    public function AutoLootInject() {
        UtilsBase.PrintChatText("Trying to inject to autoloot");

        var proto = getAutoLootProto();
        if (proto) {
            clearInterval(autoLootInjectInterval);

            UtilsBase.PrintChatText("Found prototype");

            if (!proto.OpenBox) {
                UtilsBase.PrintChatText("Unsupported version AutoRepair version");
                return;
            }

            var wrapper:Function = function() {
                UtilsBase.PrintChatText("autoLootInstance and autoLootArgs set");
                Main.s_app.autoLootInstance = this;
                Main.s_app.autoLootArgs = arguments;
            };

            if (proto.OpenBox.orig) {
                UtilsBase.PrintChatText("Aleady injected, refreshing injection");
                wrapper.orig = proto.OpenBox.orig;
            } else {
                UtilsBase.PrintChatText("Injection done");
                wrapper.orig = proto.OpenBox;
            }

            proto.OpenBox = wrapper;
        }
    }

    public function DynelAdded(id:ID32) {
        var dynel:Dynel = Dynel.GetDynel(id);

        if (dynel.GetStat(_global.Enums.Stat.e_CarsGroup) != 3) {
            return;
        }

        if (!isNyr(dynel.GetPlayfieldID())) {
            currentElite = 0;
            return;
        }

        if (dynel.GetName() != LURKER_NAME) {
            return;
        }

        var maxHP:Number = dynel.GetStat(1);
        var oldElite = currentElite;
        if (maxHP == LURKER_MAX_HP_17) {
            currentElite = 17;
        } else if (maxHP == LURKER_MAX_HP_10) {
            currentElite = 10;
        } else if (maxHP == LURKER_MAX_HP_5) {
            currentElite = 5;
        } else if (maxHP == LURKER_MAX_HP_1) {
            currentElite = 1;
        } else if (maxHP == LURKER_MAX_HP_SM) {
            currentElite = 0;
        } else {
            UtilsBase.PrintChatText("Can't determine lurker level. MaxHP: " + maxHP);
        }

        if (oldElite != currentElite) {
            UtilsBase.PrintChatText("Elite level set to: " + currentElite);
        }
    }


    private function getMaxElite():Number {
        var maxIP:Number = Character.GetClientCharacter().GetStat(2000767);
        if (maxIP >= 1700) {
            return 17;
        }
        if (maxIP >= 1000) {
            return 10;
        }
        if (maxIP >= 450) {
            return 5;
        }
        if (maxIP >= 50) {
            return 1;
        }
        return 0;
    }

    private function isNyr(playfieldId:Number):Boolean {
        return playfieldId == NYR_PLAYFIELD_ID || playfieldId == NYR_E10_PLAYFIELD_ID;
    }

    private function shouldAskQuestion():Boolean {
        var maxElite = getMaxElite();
        var nyrOnCooldown:Boolean = isNyrOnCooldown();
        var nyr:Boolean = isNyr(Character.GetClientCharacter().GetPlayfieldID());

        UtilsBase.PrintChatText("Are we in NYR? " + nyr);
        UtilsBase.PrintChatText("Is NYR on CD? " + nyrOnCooldown);
        UtilsBase.PrintChatText("What is the max NYR level currently available to us? " + maxElite);
        if (nyr) {
            UtilsBase.PrintChatText("What is the NYR elite level we are in? " + currentElite);
        }

        if (nyr && currentElite > 0 && maxElite > currentElite && !isNyrOnCooldown) {
            UtilsBase.PrintChatText("We should ask the question!");
            return true;
        }

        UtilsBase.PrintChatText("No need to ask the question!");
        return false;
    }

    private function isNyrOnCooldown():Boolean {
        return Character.GetClientCharacter().m_InvisibleBuffList[NYR_ELITE_LOCK] != undefined;
    }

    private function getAutoLootProto() {
        return _global.com.fox.AutoRepair.AutoRepair.prototype;
    }

}
