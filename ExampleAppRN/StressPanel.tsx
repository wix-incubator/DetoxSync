import React, {useCallback, useEffect, useRef, useState} from 'react';
import {Button, Settings, StyleSheet, Text, View} from 'react-native';

// Timer stress for wix/Detox#4966: continuously creates short, non-repeating
// timers (tracked by DetoxSync's JS timer resource) and clears many of them
// before they fire, so both createTimer and deleteTimer run constantly.

const BATCH_SIZE = 20; // timers created per tick
const TICK_MS = 5; // delay between batches (self-rescheduling setTimeout)
const MAX_DURATION_MS = 100; // timer durations are 0..100 ms (< 1.5 s timeout)
const CLEAR_RATIO = 0.6; // share of timers cleared before they fire
const UI_UPDATE_MS = 500;

function isAutoStart(): boolean {
  const value = Settings.get('TimerStressAutoStart');
  return value === true || value === 1 || value === 'YES' || value === 'yes' || value === 'true';
}

export default function StressPanel() {
  const running = useRef(false);
  const loop = useRef<ReturnType<typeof setTimeout> | null>(null);
  const counts = useRef({created: 0, cleared: 0, fired: 0});
  const pending = useRef<Array<ReturnType<typeof setTimeout>>>([]);
  const [isRunning, setIsRunning] = useState(false);
  const [shown, setShown] = useState(counts.current);

  const tick = useCallback(() => {
    if (!running.current) {
      return;
    }
    const c = counts.current;
    for (let i = 0; i < BATCH_SIZE; i++) {
      const id = setTimeout(() => {
        c.fired++;
      }, Math.floor(Math.random() * MAX_DURATION_MS));
      c.created++;
      pending.current.push(id);
    }
    // Clear a share of the outstanding timers before they fire.
    const list = pending.current;
    const keep: typeof list = [];
    for (const id of list) {
      if (Math.random() < CLEAR_RATIO) {
        clearTimeout(id);
        c.cleared++;
      } else {
        keep.push(id);
      }
    }
    // Drop handles of timers that have most likely fired already.
    pending.current = keep.slice(-200);
    loop.current = setTimeout(tick, TICK_MS);
  }, []);

  const start = useCallback(() => {
    if (running.current) {
      return;
    }
    running.current = true;
    setIsRunning(true);
    tick();
  }, [tick]);

  const stop = useCallback(() => {
    running.current = false;
    setIsRunning(false);
    if (loop.current) {
      clearTimeout(loop.current);
      loop.current = null;
    }
  }, []);

  useEffect(() => {
    const ui = setInterval(() => setShown({...counts.current}), UI_UPDATE_MS);
    if (isAutoStart()) {
      start();
    }
    return () => {
      clearInterval(ui);
      stop();
    };
  }, [start, stop]);

  return (
    <View style={styles.panel}>
      <Button
        testID="timerStressButton"
        title={isRunning ? 'Stop JS Timer Stress' : 'Start JS Timer Stress'}
        onPress={isRunning ? stop : start}
      />
      <Text testID="timerStressCounts">
        created {shown.created} / cleared {shown.cleared} / fired {shown.fired}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  panel: {alignItems: 'center', marginTop: 16},
});
