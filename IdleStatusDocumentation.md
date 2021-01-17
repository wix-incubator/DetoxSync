# Idle Status Documentation

DetoxSync provides the `idleStatusWithCompletionHandler:` method as means of querying the system of its status. The completion handler is called with a string, describing the idle status of the system. A typical response looks like this:

```
The system is busy with the following tasks:

Dispatch Queue
⏱ Queue: “Main Queue (<OS_dispatch_queue_main: com.apple.main-thread>)” with 3 work items

Timer
⏱ Timer with fire date: 2021-01-17 18:47:53 +0200 (fire interval: 0.9999969005584717) repeats: NO repeat interval: 0>

UI Elements
⏱ 1 view animation pending
```

Each section describes the busy component—a sync resource—and some information from the component, attempting to shed more light on why the component is busy.

This document aims to describe each component, how it is tracked and what can cause it to become busy.

### Sync Resources

#### Delayed Perform Selector

This sync resource tracks Objective C selectors scheduled to run in the future, using API such as `-[NSObject performSelector:withObject:afterDelay:]`. Such delayed selectors are tracked for run loops that are tracked by the system.

A typical idle status response:

```
Delayed Perform Selector
⏱ 2 pending selectors
```

Once all pending selectors have been called, this sync resource will become idle.

#### Dispatch Queue

This sync resource tracks [dispatch queues](https://developer.apple.com/documentation/dispatch/dispatch_queue?language=objc) and their [work items](https://developer.apple.com/documentation/dispatch/dispatch_work_item?language=objc). Once a work item is submitted to a tracked dispatch queue, the sync resource is considered busy.

A typical idle status response:

```
Dispatch Queue
⏱ Queue: “Main Queue (<OS_dispatch_queue_main: com.apple.main-thread>)” with 3 work items
```

Once all pending work items have been executed, the sync resource will become idle.

#### Run Loop

The run loop sync resource tracks [run loops](https://developer.apple.com/documentation/foundation/nsrunloop) and their states. A run loop is considered idle if it is waiting for their monitored sources. Once the run loop wakes up due to one of its sources, it is considered busy.

During the normal lifecycle of an app, its run loops normally switch often between busy and idle states, and no special significance should be paid to a busy run loop, as it is usually accompanied by other busy sync resources, which better describe what the system is doing.

A typical idle status response:

```
Run Loop
⏱ “Main Run Loop”
```

#### One-time Event

One-time events are single, one-off events which start at some point during the lifetime of the app, and once finished, are released. The system is considered idle if no such events are currently tracked.

One-time events include:

- Network requests
- Special animations
- Special application modes
- Gesture recognizer handling
- Scrolling
- Special run loop operations
- React Native load
- User provided custom events

Each one-time event description may include an object and/or other identifiable information to help hint what the event is.

A typical idle status response:

```
One Time Events
⏱ “Network Request” with object: “URL: “https://jsonplaceholder.typicode.com/todos/1””
```

This idle resource is considered idle once all tracked one-time events are finished.

#### Timer

This sync resource tracks [run loop timers](https://developer.apple.com/documentation/foundation/nstimer) and [display links](https://developer.apple.com/documentation/quartzcore/cadisplaylink). Once a timer or display link is scheduled with a tracked run loop, it is automatically tracked by the system, and the sync resource becomes busy.

A typical idle status response:

```
Timer
⏱ Timer with fire date: 2021-01-17 18:47:53 +0200 (fire interval: 0.9999969005584717) repeats: NO repeat interval: 0>
⏱ Timer with fire date: 2021-01-17 18:47:53 +0200 (fire interval: 1.499957919120789) repeats: NO repeat interval: 0>
⏱ Timer with fire date: 2021-01-17 18:47:53 +0200 (fire interval: 0.9999970197677612) repeats: NO repeat interval: 0>
⏱ Timer with fire date: 2021-01-17 18:47:53 +0200 (fire interval: 0.9999929666519165) repeats: NO repeat interval: 0>
⏱ Timer with fire date: 2021-01-17 18:47:53 +0200 (fire interval: 0.9999979734420776) repeats: NO repeat interval: 0>
```

For timers, the idle status descriptions provides the fire date (in system time zone), the fire time interval, whether the timer repeats and its repeat interval. For display links, it displays the object description.

The idle resource is considered idle once all tracked timers are either cancelled or fired, and are no longer tracked.

#### UI Elements

This sync resource tracks [views](https://developer.apple.com/documentation/uikit/uiview?language=objc), [their controller](https://developer.apple.com/documentation/uikit/uiviewcontroller?language=objc), [layers](https://developer.apple.com/documentation/quartzcore/calayer?language=objc), lifecycle and animations.

Tracked event categories include:

- View display (draw) and layout
- Layer display and layout
- View controller appearance and disappearance
- View animations
- CA (layer) animations
- Layers pending animation

Each event is tracked independently, and the system is considered busy if at least one even is tracked in any category.

Depending on the depth of the view hierarchy, view and layer display & layout counts can appear large, but those are typically untracked soon after they are needed. Controller appearance is usually tied to a transition animation. View and CA animations depend on the delay and duration provided by the developer, as well as animations set to repeat. 

**Due to the decentralized nature of view and CA animations, it is impossible to provide precise information of which view or layer are being animated. It is up to developers to be familiar with their apps.** Certain special views, such as [activity indicator views](https://developer.apple.com/documentation/uikit/uiactivityindicatorview?language=objc), can infinitely animate when displayed, and will keep the system busy. Ensure your app removes them when idle, or stops their animation.

A typical idle status response:

```
UI Elements
⏱ 1 layer awaiting layout
⏱ 3 layers pending animation
⏱ 3 view animations pending
⏱ 2 CA animations pending
```

The idle resource is considered idle when there are no active events in all categories.

#### JS Timer

This sync resource tracks JS timers in React Native applications, started with `setTimeout()`. When a JS timer is started, it is automatically tracked by the system, and the sync resource becomes busy.

A typical idle status response:

```
JS Timer
⏱ 8
⏱ 57
```

For each JS timer, the timer ID is printed, as returned by `setTimeout()`. You can use this ID to investigate where in your code the timer was started.

The idle resource is considered idle once all tracked timers are either cancelled or fired, and are no longer tracked.