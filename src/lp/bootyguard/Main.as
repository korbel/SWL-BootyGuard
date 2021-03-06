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
import com.GameInterface.WaypointInterface;
import lp.bootyguard.utils.ArrayUtils;

class lp.bootyguard.Main {

    private static var s_app:Main;

    private static var NYR_PLAYFIELD_ID = 5710;
    private static var NYR_E10_PLAYFIELD_ID = 5715;
    private static var NYR_SM_LOCK = 7961764;
    private static var NYR_ELITE_LOCK = 9125207;

    public static var LURKER_MAX_HP_17 = 77213848;
    public static var LURKER_MAX_HP_10 = 43199824;
    public static var LURKER_MAX_HP_5 = 10905556;
    public static var LURKER_MAX_HP_1 = 3262582;
    public static var LURKER_MAX_HP_SM = 3262582;

    public static var LURKER_DYNEL_TYPES_17 = [35448, 35449];
    public static var LURKER_DYNEL_TYPES_10 = [35448, 35449];
    public static var LURKER_DYNEL_TYPES_5 = [37256, 37255];
    public static var LURKER_DYNEL_TYPES_1 = [32433, 32030];
    public static var LURKER_DYNEL_TYPES_SM = [37265, 37263];

    public static var LURKER_NAME:String = LDBFormat.LDBGetText(51000, 32030);

    private var autoLootInjectInterval:Number;
    private var autoLootInstance:Object;
    private var autoLootArgs:Array;

    private var currentElite:Number = null;

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
        WaypointInterface.SignalPlayfieldChanged.Connect(SlotPlayfieldChanged, this);

        autoLootInjectInterval = setInterval(Delegate.create(this, AutoLootInject), 1000);
    }

    public function OnUnload() {
        clearInterval(autoLootInjectInterval);

        WaypointInterface.SignalPlayfieldChanged.Disconnect(SlotPlayfieldChanged, this);

        Nametags.SignalNametagAdded.Disconnect(DynelAdded, this);
        Nametags.SignalNametagRemoved.Disconnect(DynelAdded, this);
        Nametags.SignalNametagUpdated.Disconnect(DynelAdded, this);

        CharacterBase.SignalClientCharacterOfferedLootBox.Disconnect(SlotClientCharacterOfferedLootBox, this);
    }

    public function SlotPlayfieldChanged(playfieldId:Number) {
        if (playfieldId == NYR_PLAYFIELD_ID || playfieldId == NYR_E10_PLAYFIELD_ID) {
            Nametags.SignalNametagAdded.Connect(DynelAdded, this);
            Nametags.SignalNametagRemoved.Connect(DynelAdded, this);
            Nametags.SignalNametagUpdated.Connect(DynelAdded, this);
            Nametags.RefreshNametags();
        } else {
            Nametags.SignalNametagAdded.Disconnect(DynelAdded, this);
            Nametags.SignalNametagRemoved.Disconnect(DynelAdded, this);
            Nametags.SignalNametagUpdated.Disconnect(DynelAdded, this);
            currentElite = null;
        }
    }

    public function SlotClientCharacterOfferedLootBox() {
        if (shouldAskQuestion()) {
            Question();
        } else {
            Continue();
        }
    }

    public function Question() {
        var message = Format.Printf("You are about to open an E%d box.\nAre you sure you want to continue?", currentElite);
        var dialogIF = new DialogIF(message, _global.Enums.StandardButtons.e_ButtonsYesNo);
        dialogIF.SignalSelectedAS.Connect(Answer, this);
        dialogIF.Go();
    }

    public function Answer(buttonId:Number) {
        if (buttonId == _global.Enums.StandardButtonID.e_ButtonIDNo) {
            DistributedValue.SetDValue("lootBox_window", false);
        } else {
            Continue();
        }
        autoLootInstance = undefined;
    }

    public function Continue() {
        if (autoLootInstance) {
            var proto = getAutoLootProto();
            if (proto.OpenBox.orig) {
                proto.OpenBox.orig.apply(autoLootInstance, autoLootArgs);
            } else {
                AutoLootInject();
            }
        }
        autoLootInstance = undefined;
    }

    public function AutoLootInject() {
        var proto = getAutoLootProto();
        if (proto) {
            clearInterval(autoLootInjectInterval);

            if (!proto.OpenBox) {
                return;
            }

            var wrapper:Function = function() {
                Main.s_app.autoLootInstance = this;
                Main.s_app.autoLootArgs = arguments;
            };

            if (proto.OpenBox.orig) {
                wrapper.orig = proto.OpenBox.orig;
            } else {
                wrapper.orig = proto.OpenBox;
            }

            proto.OpenBox = wrapper;
        }
    }

    public function DynelAdded(id:ID32) {
        if (currentElite != null) { 
            return;
        }

        var dynel:Dynel = Dynel.GetDynel(id);

        if (dynel.GetStat(_global.Enums.Stat.e_CarsGroup) != 3) {
            return;
        }

        if (dynel.GetName() != LURKER_NAME) {
            return;
        }

        var maxHP:Number = dynel.GetStat(1);
        var type:Number = dynel.GetStat(112);

        if (maxHP == LURKER_MAX_HP_17 && ArrayUtils.Contains(LURKER_DYNEL_TYPES_17, type)) {
            currentElite = 17;
        } else if (maxHP == LURKER_MAX_HP_10 && ArrayUtils.Contains(LURKER_DYNEL_TYPES_10, type)) {
            currentElite = 10;
        } else if (maxHP == LURKER_MAX_HP_5 && ArrayUtils.Contains(LURKER_DYNEL_TYPES_5, type)) {
            currentElite = 5;
        } else if (maxHP == LURKER_MAX_HP_1 && ArrayUtils.Contains(LURKER_DYNEL_TYPES_1, type)) {
            currentElite = 1;
        } else if (maxHP == LURKER_MAX_HP_SM && ArrayUtils.Contains(LURKER_DYNEL_TYPES_SM, type)) {
            currentElite = 0;
        } else {
            UtilsBase.PrintChatText("BootyGuard: Can't determine lurker level. MaxHP: " + maxHP + ", Type: " + type);
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

    private function shouldAskQuestion():Boolean {
        var maxElite:Number = getMaxElite();
        var nyrOnCooldown:Boolean = isNyrOnCooldown();

        if (currentElite != null && currentElite > 0 && maxElite > currentElite && !nyrOnCooldown) {
            return true;
        }

        return false;
    }

    private function isNyrOnCooldown():Boolean {
        return Character.GetClientCharacter().m_InvisibleBuffList[NYR_ELITE_LOCK] != undefined;
    }

    private function getAutoLootProto() {
        return _global.com.fox.AutoRepair.AutoRepair.prototype;
    }

}
