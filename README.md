<div align="center">

<img width="256" height="256" alt="fork3xtransparent" src="https://github.com/user-attachments/assets/c79cab95-49d5-444d-9c76-618e526f2b52" />

## Welcome to the Fork3X GitHub!

### [Try On Roblox](https://www.roblox.com/join/ix61y) | [Roblox Model](https://create.roblox.com/store/asset/74515839665793/Fork3X-Building-Tools-F3X-MOD)

### Fork3X is a mod of F3X's building tools and a love letter to modding. ❤️

</div>

It brings to users - both in-game and in Studio - a wonderfully simple set of powerful tools that make building easier and faster.

The goal of Fork3X is to **offer new features, better performance, and let developers stand out with a customisability that lets them make THEIR tools.** It's here to help your game, but also to make it.

Do note Fork3X doesn't attempt to surpass the built-in Studio Tools, although there may be useful features Studio doesn't have!

## Table of Contents

- [Setup](#setup)
  * [You can find the latest release here](#you-can-find-the-latest-release-here)
- [Features](#features)
  * [New tools](#new-tools)
  * [Security - and many other settings](#security---and-many-other-settings)
  * [UI Styling](#ui-styling)
  * [Many extra features](#many-extra-features)
  * [Mobile compatibility](#mobile-compatibility)
  * [F3X servers replacement](#f3x-servers-replacement)
  * [Optimisations](#optimisations)
  * [Help is always available](#help-is-always-available)
- [Q&A](#qa)
  * [Fork3X or F3X?](#fork3x-or-f3x)
  * [Will raidRoleplay work?](#will-raidroleplay-work)
  * [Is there a plugin?](#is-there-a-plugin)
  * [What is every new feature in Fork3X?](#what-is-every-new-feature-in-fork3x)
  * [Your fork damaged my game!](#your-fork-damaged-my-game)
  * [How shall I implement Fork3X?](#how-shall-i-implement-fork3x)
  * [How do I ... in Fork3X?](#how-do-i--in-fork3x)
  * [How are profiles and themes different?](#how-are-profiles-and-themes-different)
  * [What security features can be covered with Fork3X?](#what-security-features-can-be-covered-with-fork3x)
  * [I am using v3.1.1 or lower and experience build losses!](#i-am-using-v311-or-lower-and-experience-build-losses)
  * [Do I have to credit you in the description?](#do-i-have-to-credit-you-in-the-description)
  * [I am GigsD4X and am disturbed by Fork3X, what can I do?](#i-am-gigsd4x-and-am-disturbed-by-fork3x-what-can-i-do)
  * [I hate the new UI!](#i-hate-the-new-ui)
  * [How is Fork3X's code?](#how-is-fork3xs-code)
  * [Can I use a module inside Fork3X for my own projects?](#can-i-use-a-module-inside-fork3x-for-my-own-projects)
  * [I see you help for BTG, can I hire you for my building game?](#i-see-you-help-for-btg-can-i-hire-you-for-my-building-game)
  * [Can I change the number of save slots?](#can-i-change-the-number-of-save-slots)
  * [Can I use my own serialization module?](#can-i-use-my-own-serialization-module)
  * [I'm afraid hackers use flaws with Fork3X](#im-afraid-hackers-use-flaws-with-fork3x)
  * [I want to support Fork3X!](#i-want-to-support-fork3x)
  * [Why is the DevForum page outdated?](#why-is-the-devforum-page-outdated)
  * [If Fork3X can't be on the Creator Store, is it because it's unsafe?](#if-fork3x-cant-be-on-the-creator-store-is-it-because-its-unsafe)

 
<sup>(generated with [markdown-toc](https://ecotrust-canada.github.io/markdown-toc/); check out their project too!)</sup>

## Setup

### You can find the latest release [here](https://github.com/VikkoMakesStuff/Fork3X/releases/latest)

[This wiki page](https://github.com/VikkoMakesStuff/Fork3X/wiki/Installing-and-Maintaining-Fork3X) explains you how to setup Fork3X, and gives many tips that help you make your game better.

## Features

### New tools

Fork3X introduces new, simple tools that help the player building without headache.

> **Marketplace Tool**
>
> This seemingly basic tool allows users to find decals easily. [With more advanced configuration](https://github.com/VikkoMakesStuff/Fork3X/discussions/9), it can even look up meshes!
>
> **Text Tool**
>
> A tool that allows users to write text on their part. Rich text is also supported, offering a great palette of possibilities to players to customise their text.
>
> **Transformation Tool**
>
> This tool allows users to use the CSG (aka unions) API to create complex shapes off basic parts. It also comes with complete saving and in-game separation, two features the normal CSG API doesn't offer.
> 
> v3.2.2 (still being worked on) also allows people to change their parts' shape and type. Developers can add their own sub-types, allowing players to configure their parts to go even further.
> 
> **Attachment Tool**
>
> Offers the players the ability to manipulate attachments. Those are points whose position are relative to the part, and can be used to accurately manage constraints and effects like particle emitters.

### Security - and many other settings

You can learn how to configure the Options module and discover how you can configure many options with [the slowly expanding wiki](https://github.com/VikkoMakesStuff/Fork3X/wiki/Installing-and-Maintaining-Fork3X) to easily make your game safer and better for your users.

### UI Styling

Roblox's built-in UI styling is supported by Fork3X, making customisability easier and more future-proof than ever. Fork3X also introduces components that allow the developers to add UI object (Roact included) to the interface of Fork3X.

### Many extra features

> **Focus-wise coordinates**
>
> The new focus-wise mode for the move and rotate tools allow the user to move a whole selection with extreme precision by moving the "focus" with the coordinates. In Global mode, the focus is the whole selection's boundaries that's used as a reference, similarly to models' pivots.
>
> **Mesh resizing**
>
> When resizing parts with a mesh, F3X used to not resize the meshes when doing so. Fork3X allows this to be done.
>
> **New properties here and there**
>
>Fork3X offers more properties to configure with most tools, including Massless, decal color and such.
>
> **Improved weld tool**
>
> The weld tool has become the constraint tool. You can now by default add ropes, rods and hinges to your part to have an easier time building machines and wacky mechanisms.
>
> In the future v3.2.2, YOU will be able choose the constraints you want. This will open a large palette of possibilities and control over what you deem safe and useful for your game.
>
> **New effects with the Decorate Tool**
>
> Push the Roblox engine to its limits with 3 new effects added to the Decorate Tool: **Particle Emitters, Selection Boxes and Highlights.** This allows you (and players) to create breathtaking effects and builds.
>
> **Accurate mesh size control**
>
> Having to resize a mesh to fit to your part's boundaries has always been a painful process with meshes with F3X. [With some tweaking](https://github.com/VikkoMakesStuff/Fork3X/discussions/9), you can say goodbye to these issues, and gain precious minutes.
>
> **Saving/Loading**
>
> Allowing your users to save hours of work is essential, and this is what Fork3X wants to make possible. v3.2.1 introduced a new Save/Load interface that offers previews, compression, and a readable encoding for creators to contribute to that objective.

### Mobile compatibility

Although not a top priority, Fork3X narrows the gap between the keyboard-mouse and touch device experiences. Multiple utility and keybinds can now be triggered via a button, making them accessible to the majority of your playerbase.

### F3X servers replacement

Fork3X is suited to - if possible - no longer depend on F3X servers, but rather directly on Roblox's services. [With some setup here](https://github.com/VikkoMakesStuff/Fork3X/discussions/9), you can restore the previous experience of F3X with the servers being functional.

### Optimisations

Fork3X uses a lot of clever methods to prevent lag spikes with demanding utilities such as the explorer or rectangle selecting. This should make the general experience more comfortable for the average user.

### Help is always available

You can always explore the wiki [here](https://github.com/VikkoMakesStuff/Fork3X/wiki) (still a work-in-progress) and ask for help [here](https://github.com/VikkoMakesStuff/Fork3X/discussions/categories/q-a) in order to make Fork3X work how you want it to work.

### A detailed list of the new features can be found here.

## Q&A

You can find answers to many questions below:

### Fork3X or F3X?

F3X has become a standard in in-game building, mostly for its intuitiveness. On the other hand, **Fork3X aims to offer more flexibility and unique features that make building faster.** Both are considered as equal, and it's up to the developer themself to choose.

- Choose Fork3X if you look for more features and a tool that's meant to be modified.
- Choose F3X for a bug-free, rock-solid tool that will always work. It may sometimes be more intuitive. 

### Will raidRoleplay work?

Although raidRoleplay is old, it has proven to work well with Fork3X. Just expect the log to not print actions related to the newer tools.

### Is there a plugin?

Yes! Although it isn't on the Creator marketplace for the reason you can find [here](#if-fork3x-cant-be-on-the-creator-store-is-it-because-its-unsafe), you can find out how to setup the plugin [here](https://github.com/VikkoMakesStuff/Fork3X/wiki/Installing-and-Maintaining-Fork3X#on-github-plugin-and-in-game).

### What is every new feature in Fork3X?

You can find a list of them right here (it is slightly outdated):

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
 
• A ConsiderPart function to not allow people to select specific parts and not consider them when pointing at them

• Prism selections (aka select parts in a part) won't select forbidden objects anymore (mostly objects in terrain)

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

• Better access to the built-in notifications system with V2 UI (just add any notification you want via CustomCoreConnections with the Core.Notifications table and Core.NewNotification event)

• A button for prism selection (aka select parts in a part)

• A rectangle selection toggle for mobile users (so their camera locks when rectangle selecting)

• Several improvements concerning the explorer's children's label

• Better documentation for multiple tools

• Themes and profiles to customise the UI

• Sounds (you can put their volume to 0 if it disturbs you)

• Attachments support

• Webhook support: send messages to a webhook through your own module or the built-in one (made by someone whose resource has been scrapped)

• Added an option to not cause handles to lock the camera

</details>

### Your fork damaged my game!

Fork3X is under a public license, which means I take no responsibility on a misuse or aftereffects of Fork3X. You can get some tips for a good implementation below.


### How shall I implement Fork3X?

You can read [this wiki page](https://github.com/VikkoMakesStuff/Fork3X/wiki/Installing-and-Maintaining-Fork3X) to find much information to implement your tools well. When upgrading to Fork3X, always remember to let people choose between the original theme (GigsDark) and the new one (CementDark). 

If you only want to use GigsDark, feel free to replace the CheckTheme setting as done here:

```luau
CheckTheme = function(Core, Player)
	local Theme = Core.Themes.GigsDark

	return Theme.GigsDark, Theme.Tokens.GigsDarkTokens, Theme.Components
end,
```

### How do I ... in Fork3X?

If you have a GitHub account, you can always make a Q&A post in Discussions if you want to get help to accomplish something. Remember each question asked there helps everyone!

### How are profiles and themes different?

Profiles were a former take in customisability, which were essentially based on UI objects. They were very limited and lacked of intuitiveness and should no longer be used in new works.
  
Themes are a modern and simpler way to customise the interface. They modify the UI without letting any footprint with components and a CSS (cascading style sheets) system. It's all about:

- Using a Roblox built-in tool to edit different types of UI item.
  
- Learning how to use selectors and be able to inject UI objects inside the UI.

You need little to no scripting knowledges to use them. You can even edit Roact (UI inside script very brief) objects without Roact, which is really reassuring for most people (me included). A tutorial about this is planned, so stay tuned!

### What security features can be covered with Fork3X?

You can find the answer in the Security dropdown [here](#what-is-every-new-feature-in-fork3x)!

### I am using v3.1.1 or lower and experience build losses!

Roblox is infamously known for having data serialisation that's problematic with the JSON system. This caused inconsistencies that caused the whole system to become very lossy.

Fork3X uses a trick to prevent this serialisation, which should prevent those issues to occur.

### Do I have to credit you in the description?

The credits are already included in the tools. I really appreciate whenever someone also adds them in the description, so it's all up to you.

However, because the project is unlicensed, **the creator of the main project still has rights on the use of their repository!** Make sure to not erase any of the contributors' credits, as this may go against their rights, and so cause eventual takedowns.

### I am GigsD4X and am disturbed by Fork3X, what can I do?

In attempt to comply with the potential rights behind F3X, I:

- Earn nothing from the project
- Kept the credits
- Am open to merge both projects (Right to Fork)

I am always open to discussion if the project appears to be a problem for the main one.

### I hate the new UI!

Even if v3.2.0 brings essential improvements to the UI, note that UI designing isn't my thing and that it's completely fine to not like it.

Make sure to follow [this](#how-shall-i-implement-fork3x) in order to revert the previous interface.

### How is Fork3X's code?

I'd consider it as average. Although there is no type checking, the code should be mostly clean.

Anyway, don't tire yourself trying to find crap in the code. It's just F3X.

### Can I use a module inside Fork3X for my own projects?

I will try by 2026 to extract a few parts of Fork3X and open-source them alone. Some modules I made - mainly CSGTree - are still tied to Fork3X's libraries and code, which may be problematic when looking to use them alone, hence why it's worth waiting for them to get properly open-sourced.

### I see you help for BTG, can I hire you for my building game?

**You don't.** I am not for hire, and my point to contribute to this game is to understand the expectations of the community of a building game. **Any request to hire me will be ignored.**

### Can I change the number of save slots?

Yes! As of v3.2.0, this can be changed, along with size limits.

Note that Roblox has a built-in datastore size limit of 4 MB, so avoid going over this quota with all saves together, despite the server's effort to compress the save.

### Can I use my own serialization module?

This is a feature that will probably get added. In the meantime, this is very possible. Simply replace the latest serialization module with your module, make sure to adapt your system to the original one, and it should work.

### I'm afraid hackers use flaws with Fork3X

The only particularity a hacker should have compared to players is firing functions at a high rate, causing the server to lag (aka DDoS).

Fork3X makes sure of the following to prevent attacks:

- Any cooldown is handled by **BOTH the server and the client.** This means that if the hacker fires a bunch of events, any cooldown added by the developers will still apply.
- **Fork3X always restricts the property that can be changed.** Hackers can only modify what a player can modify, so there shouldn't be dangerous flaws that give full control over the game.
- When many events are fired, Fork3X throttles. This makes DDoS way slower and dissuasive, and lets moderators enough time to prevent an attack to happen.

This means there shouldn't be any particular flaw that may greatly endanger the game.

### I want to support Fork3X!

Not only I am not interested in earning any money with this project, I also want to respect the original creator's potential rights. Earning money directly (if it's in a game, it's okay) off someone's work that's free is very disrespectful and should be avoided.

### Why is the DevForum page outdated?
  
As I am heavily against age gating the access to culture, I don't want to complete an age check nor motivate people to give out their sensitive information simply to report bugs and give feedback.

GitHub is the main place for the Fork3X community as anyone can see what bugs got reported and such, but I might also let people DM me on Discord (13+, please respect this rule as it's here for your safety) to not force people to have a GitHub account to contribute.

### If Fork3X can't be on the Creator Store, is it because it's unsafe?
  
The real reason Roblox blocks Fork3X is unknown, but Fork3X uses a method (AssetService:LoadAssetAsync) to estimate a mesh's size that Roblox blacklisted.

This function is sandboxed, meaning that Fork3X will **never**  insert content against your will. It's also simply used to insert the original MeshPart with its original size, and so accurately resize the mesh to the object.

If this answer doesn't satisfy you, the code is available here if you want to make sure it isn't obfuscated.

