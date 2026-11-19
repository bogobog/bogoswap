### Tool Purpose and Concepts

BogoSwap is a tool whose purpose is to provide the ability to automatically swap a preconfigured item into a character's preselected equipment position when a preconfigured condition is met.  BogoSwap should provide slash commands to configure all of the settings it defines.  It should also provide a minimal ImGUI interface for managing those same settings.

### Supported Features
For the initial feature support, BogoSwap should concentrate on supporting item switching based on an effect trigger.  Specifically, a user should be able to provide the name of a buff effect, the name of two separate items in their inventory, and the name of a slot in their active equipment.  One specified item is the item to swap into place when the effect is matched and the other is the item to swap into place when the effect is NOT matched.  With that information, BogoSwap should watch for the presence of the specified buff effect in the character's buffs and swap the first specified item into the specified equipment slot when the effect is present.  When the effect is not present, BogoSwap should swap in the second specified item.

BogoSwap should also provide support for pausing its own processing on command so that the tool continues to run, but takes no action until it is unpaused.

### Config Options
TriggerEffectName - name of the buff effect to watch for
SwapEquipmentSlot - name of the equipment slot for swapping
MatchItemName - name of the item to swap in when the trigger effect is present
NoMatchItemName - name of the item to swap in when the trigger effect is NOT present
