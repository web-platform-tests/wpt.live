#!/usr/bin/env python

import argparse
import logging
import Queue
import subprocess
import threading

class Restartable(object):
    '''A subprocess that is intended to run indefinitely unless explicitly
    restarted.'''
    def __init__(self, *args, **kwargs):
        self._message_bus = Queue.Queue()
        self._restart_lock = threading.Lock()
        self._args = args
        self._kwargs = kwargs

    def _watch(self):
        self.proc.communicate()
        self._signal()

    def _signal(self):
        lock = threading.Lock()
        lock.acquire()
        self._message_bus.put(lock)
        lock.acquire()

    def run_forever(self):
        '''Execute the subprocess using the arguments provided to the
        constructor. If the subprocess exits without a request for restarting,
        raise an exception.'''

        while True:
            self.proc = subprocess.Popen(*self._args, **self._kwargs)
            thread = threading.Thread(target=self._watch)
            thread.start()

            result = self._message_bus.get()

            try:
                if self.proc.poll() is not None:
                    raise Exception('Restartable exited unexpectedly')

                self.proc.terminate()

                # Wait for child process to end
                self._message_bus.get().release()
            finally:
                # Signal completion to calling thread
                result.release()

    def restart(self):
        '''Restart the subprocess.'''
        with self._restart_lock:
            self._signal()

class Sentinel(object):
    '''Execute a command as a subprocess indefinitely, invoking a callback with
    each successful execution.'''
    def __init__(self, cmd, on_success):
        self._cmd = cmd
        self._on_success = on_success

    def run_forever(self):
        '''Repeatedly execute a command. If the command is successful, invoke
        the `on_success` callback and repeat. If the command fails, raise an
        exception.'''
        while True:
            proc = subprocess.Popen(self._cmd, shell=True)
            proc.communicate()
            if proc.returncode != 0:
                raise Exception(
                    'Sentinel exited with non-zero exit code ({})'.format(self._cmd)
                )

            self._on_success(self)

def main(leader_cmd, sentinel_cmds):
    logger = logging.getLogger()
    handler = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s %(name)-12s %(levelname)-8s %(message)s')
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.setLevel(logging.DEBUG)
    child = Restartable(leader_cmd)
    errors = Queue.Queue()

    def target(subject, errors):
        try:
            subject.run_forever()
        except Exception as e:
            errors.put(e)

    def on_success(sentinel):
        logger.debug('Restarting following signal from sentinel ({})'.format(sentinel._cmd))
        child.restart()

    for sentinel_cmd in sentinel_cmds:
        sentinel = Sentinel(sentinel_cmd, on_success)
        thread = threading.Thread(target=target, args=(sentinel, errors))
        thread.daemon = True
        thread.start()

    thread = threading.Thread(target=target, args=(child, errors))
    thread.daemon = True
    thread.start()

    raise errors.get()

# foo --sentinel sync-wpt.py --sentinel sync-cert.py -- ./wpt serve
if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--sentinel', action='append', dest='sentinel_cmds',
                        help='A command that controls when the "leader" '
                             'process is restarted. The leader will be '
                             'restarted whenever this command exits with an '
                             'exit status of 0. May be repeated.')
    parser.add_argument('leader_cmd', nargs='+',
                        help='A command that should run indefinitely. It will '
                             'be restarted according to the behavior of all '
                             'provided "sentinels." If the command exits for '
                             'other reason, this command will fail.')
    args = parser.parse_args()
    main(**vars(parser.parse_args()))
