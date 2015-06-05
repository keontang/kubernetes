# Command line tool for anchnet API

## Build
To build binary, run:
```
go build .
```

## Usage
Run the binary to list usages:
```
./anchnet
```

For example, to create an instance 'test_instance' with 2 cores, 4 GB Memory, run:
```
./anchnet runinstance test_instance -c=2 -m=4
```

## Notes
The command line tool only implements necessary APIs. We expect to add more as the project goes.
