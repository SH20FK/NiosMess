import ast

import deploy


def test_activation_script_substitutes_marker_in_every_concatenated_section(monkeypatch):
    scripts = []
    monkeypatch.setattr(deploy, "remote_python", lambda client, source, **kwargs: scripts.append(source))
    marker = "/opt/niosmess/protocol-tools/protocol-v1-fixture/release.json"
    deploy.activate(object(), marker)
    assert len(scripts) == 1
    tree = ast.parse(scripts[0], feature_version=(3, 10))
    assert not any(isinstance(node, ast.Name) and node.id == "MARKER" for node in ast.walk(tree))
    assert repr(marker) in scripts[0]
    compile(tree, "remote_activation", "exec")
