import React, {Component} from 'react';
import {StyleSheet, View, Text, Button} from 'react-native';

type State = {counter: number};

export default class App extends Component<{}, State> {
  slowJSTimer: ReturnType<typeof setTimeout> | null = null;
  slowBridgeTimer: ReturnType<typeof setTimeout> | null = null;
  state: State = {counter: 0};

  _performTask() {
    let counter = 0;
    for (let i = 0; i < Math.pow(2, 25); i++) {
      counter++;
    }
  }

  _startSlowJSTimer() {
    console.log('Slowing CPU!');
    this._performTask();
    this.slowJSTimer = setTimeout(() => {
      this._startSlowJSTimer();
    }, 3500);
  }

  _startBusyBridgeTimer() {
    if (this.state.counter === 200) {
      this.clearBusyBridgeTimeout();
      return;
    }

    this.setState({counter: this.state.counter + 1}, () => {
      this.slowBridgeTimer = setTimeout(() => {
        this._startBusyBridgeTimer();
      }, 30);
    });
  }

  onSlowJSThread() {
    if (this.slowJSTimer) {
      clearTimeout(this.slowJSTimer);
      this.slowJSTimer = null;
    } else {
      this._startSlowJSTimer();
    }
  }

  clearBusyBridgeTimeout() {
    if (this.slowBridgeTimer) {
      clearTimeout(this.slowBridgeTimer);
    }
    this.slowBridgeTimer = null;
  }

  onBusyBridge() {
    if (this.slowBridgeTimer) {
      this.clearBusyBridgeTimeout();
    } else {
      this.setState({counter: 0}, () => {
        this._startBusyBridgeTimer();
      });
    }
  }

  onNetwork() {
    fetch('https://jsonplaceholder.typicode.com/photos')
      .then(response => response.json())
      .then(myJson => {
        let count = 0;
        for (const img of myJson) {
          fetch(img.thumbnailUrl).then(() => {
            console.log('Got an image');
          });
          count += 1;
          if (count >= 50) {
            return;
          }
        }
      });
  }

  componentDidMount() {
    setTimeout(() => {
      console.log('⏲ 1');

      setTimeout(() => {
        console.log('⏲ 1');
      }, 750);
    }, 750);
  }

  render() {
    return (
      <View style={styles.container}>
        <Button title="Slow JS Thread" onPress={() => this.onSlowJSThread()} />
        <Button title="Busy Bridge" onPress={() => this.onBusyBridge()} />
        <Text>Counter: {this.state.counter}</Text>
        <Button title="Network Requests" onPress={() => this.onNetwork()} />
      </View>
    );
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#F5FCFF',
  },
});
