## Tests

https://github.com/helm-unittest/helm-unittest#snapshot-testing

Install helm-unittest plugin
```
helm plugin install https://github.com/helm-unittest/helm-unittest.git --version 0.3.3
```

### Run tests
```
helm unittest . -v values-ci.yaml
```

### Update snapshots after changes
```
helm unittest . -v values-ci.yaml -u
```
