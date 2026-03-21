<div align="center">

# Fork3X 

## Current version: v3.2.0

v3.2.1 is currently being worked on, and is set to release end of the month. You can find more information [here](https://github.com/VikkoMakesStuff/Fork3X/discussions/7).

## Introduction:

Fork3X is a mod of F3X's building tools that aims to offer a wonderfully simple set of tools, alongside better customisability and control.

This fork's main goal is to allow developers to choose how they want their building tools to work, look like, and also to manage their game in a better way (if used in-game).

Note Fork3X doesn't aim to surpass built-in tools, and should be used in studio only to simplify.

</div>

<details>
<summary>Some features inside Fork3X</summary>
- <b>Marketplace Tool</b>: mostly for in-game use, allows players to search images and meshes without opening the creator store.<br/>
- <b>Text Tool</b>: write text on parts, without headache.<br/>
- <b>Transformation Tool</b>: an unique union system that allows separation and saving without built-in tools.<br/>
- <b>Many security features</b> to prevent various issues (griefing, lag bombing)<br/>
- <b>New UI system</b> that allows optimal customisability.<br/>
- <b>A bunch of settings</b> that allows you to apply lots of tweaks in a single place.<br/>
- <b>New features</b> in tools here and there.<br/>
- <b>Saving and loading</b>: as of v3.2.0, reduces greatly the size of builds without missing parts (or, you know, of what I hope).<br/>
- <b>Better mobile support</b>: rectangle and soft selecting support out of the box.<br/>
- <b>With APIs set up, no more F3X servers issues</b><br/>
- <b>A few yet considerable optimisations</b>, mostly regarding the explorer.<br/>
- <b>A wiki</b>: okay, at the time writing, there's just a nothingburger, but I'm working on expanding it.<br/>
</details>

<div align="center">

## Is Fork3X BETTER than F3X?

It's all about expectations.

Fork3X might be a more interesting option if you want a simple way to modify F3X (aka letting me suffer in my side), new features, fixes, and a wiki that's still being worked on.

Use F3X if you don't want a potential bug terrarium, but rather a rock-solid tool that's promised to always work.

The best is to try both and see which one fits you.

## I have raidRoleplay in my game, is Fork3X a good idea?

Although raidRoleplay is old, it seems to work very well when used with Fork3X. Just expect the log to not print actions done with the new tools.

## How do I get Fork3X?

As you may know, Roblox's moderation does an EXCELLENT job, and forbids Fork3X from being uploaded on the creator store.

Instead, I prefer sharing Fork3X in the following ways:

### On GitHub (plugin and in-game): 
Click on the latest version in the right tab, and install the file according to your needs.

For in-game use, insert the downloaded file by right clicking on the desired location in your game and selecting the file in Insert -> Import Roblox Model (in the new UI, this might be different in the old one).

### On Roblox (in-game): 

Open the test place in studio, and find your desired version in ServerStorage -> Version.

In order to mount the plugin, head to %localappdata%/Roblox/Plugins, and drop the file you installed.

Remember to check the Options module when used in-game! There's a lot of stuff you can tweak, mostly the old UI (you can find out how in the Q&A).

## Can I make my own fork of Fork3X?

Of course! Fork3X is under a public license (unlicense), which basically means "Here's what I made, do whatever you want with."

So, yes, you can make your fork, use it in your admin system, or even sell it (wait, no, don't do it, bad idea).

## Q&A:

</div>
<details>
<summary>Click the arrow to open the Q&A</summary>
<details>
<summary>Q: What are every new features in Fork3X?</summary>
<details>
<summary>Tools</summary>
  
**Resize Tool**:
• Scaling with the resize tool: keep proportions while resizing
• Mesh resizing
• Increments limitations will remain up-to-date with Roblox's
 
**Material Tool**:
• Shadow and massless settings wit the material tool
• Every single new materials are added and will be added if Roblox adds any automatically
• MaterialVariants support (can be blacklisted)
• Previews (NOTE: If Roblox adds any material or if you want to add material variants, please check the wiki to add their resepective previews)
 
**New Part Tool**:
• Specific instances can be blacklisted in the Options module
• New creatable instances can also be added via the Options module

**Mesh Tool**:
 • Without an API key nor HTTP requests enabled, you can convert any accessorie, gear, or mesh the creator owns to a mesh ID, a texture ID, and VertexColor in rare cases (the Firebrand 		e. g.)
• After setting up an API key, you can convert any meshpart or mesh to their respective mesh ID and texture ID
• If enabled in the settings, players can choose how they want a mesh to fit their part (if the mesh isn't returned by the F3X servers)

**Texture Tool**:
• Textures and decals can now have their tint changed
• A new thumbnail mode setting (formerly fast mode) to display images of other kinds of assets (or even players)
• Decal IDs will be converted into image IDs in any situation
 
 **Constraint Tool (formerly Weld Tool)**:
• 3 new constraints: ropes, rods and motors (I advise you to be careful with ropes and rods in public servers as people tend to use them for bad purposes)

**Decorate Tool**:
• 3 new effects: highlights, selection boxes and particle emitters

**Marketplace Tool**:
→ This tool allows people to search decals (with the very bad InsertService:GetFreeDecalsAsync() function) without an API key, and meshes (and also a better search system) with one

**Text Tool**:
→ This tool allows people to put filtered text on their parts, along with various settings and rich text support

**Transformation Tool**:
 → This tool can create unions and intersections that can be saved afterwards (as long as it isn't split)
 
**Attachment Tool**:
→ This (seemingly simple and useless) tool allows you to add and access a part's attachments without the explorer, and so offer more possibilities with certain tools

</details>
<details>
<summary>Security</summary>

• Permissions (with CheckPermission and SetPermission functions)

• Anti-unanchor bombing

• Anti-effects bombing

• Anti-player deleting (yes, you can kick people that way + it might bug so be careful)

• Anti-player characters selecting (with PlayerTolerance)

• Anti-player ungrouping (protects from death loops caused by humanoids parented in workspace)

• Anti-mesh absurd sizing (creates Z-Fighting + regularly used by hackers)

• Image blacklisting

• Anti-events overflowing (so spamming events to crash a server)

• Doom-meshes protection (spamming meshes with high triangle counts will be blocked)

 
• A ConsiderPart function to not allow people to select specific parts and not consider them 			when pointing at them

• Prism selections (aka select parts in a part) won't select forbidden objects anymore (mostly 			objects in terrain)

• Names given to parts in-game will be filtered
</details>
<details>
<summary>Optimisations</summary>
  
• Removal of getfenv() from the code

• Most deprecated functions are gone

• Replaced most functions from SupportLibrary with their Roblox counterpart (QueryInstance is	included by the way)

• Major explorer optimisations

• A few optimisations in the selection rectangle algorithm

• Various changes in the tools' code: use of BulkMoveTo, transition from Vector3 to vector, etc...

</details>
<details>
<summary>Miscellaneous</summary>
  
• Saving/Loading utility that can be managed from the Options module

• A grouping utility to make grouping and ungrouping more intuitive

• Better access to the built-in notifications system with V2 UI (just add any notification you want 		via CustomCoreConnections with the Core.Notifications table and Core.NewNotification event)

• A button for prism selection (aka select parts in a part)

• A rectangle selection toggle for mobile users (so their camera locks when rectangle selecting)

• Several improvements concerning the explorer's children's label

• Better documentation for multiple tools

• Themes and profiles to customise the UI

• Sounds (you can put their volume to 0 if it disturbs you)

• Attachments support

• Webhook support: send messages to a webhook through your own module or the built-in one 		(made by someone whose resource has been scrapped)

• Added an option to not cause handles to lock the camera
</details>
PS: this list needs to be update with v3.2.0. Sorry for the inconvenience!
</details>
<details>
<summary>Q: Your fork damaged my game!</summary>
Fork3X is under a public license, which means I take no responsibility on a misuse or aftereffects of Fork3X. You can get some tips for a good implementation below.
</details>
<details>
<summary>Q: How shall I implement Fork3X?</summary>
The UI is a major issue of a bad implementation of Fork3X. Use GigsDark (the old UI) first and make CementDark optional.
As a reminder, I'm a solo developer, and have very limited timetables. I cannot promise Fork3X to be 100% bug-free, so be careful to not implement it too quickly (keep F3X as an option).
Bug reports and questions concerning setting up certain things in Fork3X are always welcome here.
Remember to not make the security too harsh. Try to use a strike system instead, or just send messages via a webhook (yes, there's built-in support!)
</details>
<details>
<summary>Q: How do I ... in Fork3X?</summary>
Note this is only a non-exhaustive list of "tutorials" that can be found in the wiki and in the replies here (this needs to be updated, sorry for the inconvenience).
</details>
<details>
<summary>Q: Difference between profiles and themes?</summary>
Profiles were the former nightmare fuel of customisability. They consist to:
  
- Drop two "Interfaces" and "UI" folders into another folder.

- Dive into 3 hours of mental struggle to add illogical attributes to make it work well.

- ...look, it's just bad, okay?
  
Themes are the new alternative that consists to modify the UI with components and a CSS (cascading style sheets) system. It's just:
- Using a Roblox built-in tool to edit different types of UI item.
  
- Learning how to use selectors and be able to inject UI objects inside the UI.
You need little to no scripting knowledges to do so. You can even edit Roact (UI inside script very brief) objects without Roact, which is really reassuring for most people (me included). One of the first tutorials (after the API keys one) I'll make will be centered on this. Stay tuned!
</details>
<details>
<summary>Q: What security features can be covered with Fork3X?</summary>
Taken from "Q: What are every new features in Fork3X?":
• Permissions (with CheckPermission and SetPermission functions)
  
• Anti-unanchor bombing

• Anti-effects bombing

• Anti-player deleting (yes, you can kick people that way + it might bug so be careful)

• Anti-player characters selecting (with PlayerTolerance)

• Anti-player ungrouping (protects from death loops caused by humanoids parented in 				workspace)

• Anti-mesh absurd sizing (creates Z-Fighting + regularly used by hackers)

• Image blacklisting

• Anti-events overflowing (so spamming events to crash a server)

• Doom-meshes protection (spamming meshes with high triangle counts will be blocked)

• A ConsiderPart function to not allow people to select specific parts and not consider them when pointing at them

• Prism selections (aka select parts in a part) won't select forbidden objects anymore (mostly objects in terrain)

• Names given to parts in-game will be filtered
</details>
<details>
<summary>Q: I am using v3.1.1 or lower and experience build losses!</summary>
This is due to table encoding, modifying the way elements are saved when there are blanks. Everything should be fixed in v3.2.0 and above.
</details>
<details>
<summary>Q: Do I have to credit you in the description?</summary>
Doing so would be very nice, but it's not necessary as credits can be found in the building tools.
</details>
<details>
<summary>Q: I hate the new UI!</summary>
Even if v3.2.0 brings essential improvements to the UI, note that UI designing isn't my thing and that it's completely fine to not like it.

You can use back the old UI this way (from "Q: How do I ... in Fork3X?"):
</details>
<details>
<summary>Q: Why do the yellow/blue/any color bubbles stay even after unselecting?</summary>
This is not normal. That's a common tomfoolery of mine. Please report it here if it ever happens.
</details>
<details>
<summary>Q: How is Fork3X's code?</summary>
I'd consider it as average. Although there is no type checking, the code should be mostly clean.

Anyway, don't tire yourself trying to find crap in the code. It's just F3X.
</details>
<details>
<summary>Q: Can I use a module inside Fork3X for my own projects?</summary>
I will try by 2026 to extract a few parts of Fork3X and open-source them alone. This allows me to offer the cleanest samples for uses outside Fork3X.
</details>
<details>
<summary>Q: Can you help me for a project?</summary>
I know it's an unserious way to say it, but I am not made for communities. At all. You're better off checking tutorials here or ask how to do something.
</details>
<details>
<summary>Q: Can I change the number of save slots?</summary>
Yes! As of v3.2.0, this can be changed, along with size limits.

Note that Roblox has a built-in datastore size limit of 1 MB, so avoid going over this quota with all saves together, despite the server's effort to encode and reduce the save's size.
</details>
<details>
<summary>Q: Can I use my own serialization module?</summary>
This is a feature that will probably get added. In the meantime, this is very possible. Simply replace the latest serialization module with your module and everything should work as expected.
</details>
<details>
<summary>Q: Are there flaws hackers can use?</summary>
The only particularity a hacker has compared to players is firing high rates of functions, causing the server to lag.
If too many events are fired, throttling will occur, making spamming useless, in addition of general securities.
</details>
<details>
<summary>Q: I want to support Fork3X!</summary>
I don't want to earn money from Fork3X. I totally develop it as a passion, so simply using it in your game is the best way to support Fork3X.
</details>
<details>
<summary>Q: Why is the DevForum page outdated?</summary>
  
As I am heavily against age gating the access to culture, I don't want to complete an age check nor motivate people to give out their sensitive information simply to report bugs and give feedback.

GitHub is the main place for the Fork3X community as anyone can see what bugs got reported and such, but I might also let people DM me on Discord (13+, please respect this rule as it's here for your safety) to not force people to have a GitHub account to contribute.

</details>
<details>
<summary>Q: If Fork3X can't be on the Creator Store, is it because it's unsafe?</summary>

  
The real reason Roblox blocks Fork3X is unknown, but Fork3X uses a method (AssetService:LoadAssetAsync) to estimate a mesh's size that Roblox blacklisted. This function is sandboxed, meaning that Fork3X will **never**  insert content against your will.

If this answer doesn't satisfy you, the code is available here if you want to make sure it isn't obfuscated.

</details>
