#!/usr/bin/env python3
"""Exercise the actual source selection functions with a controlled random stream."""
import json

def lua(value):
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, (float, int)):
        return str(value)
    if isinstance(value, list):
        return '{' + ','.join(map(lua, value)) + '}'
    if isinstance(value, dict):
        return '{' + ','.join('[' + lua(k) + ']=' + lua(v) for k, v in value.items()) + '}'
    return 'nil'


def export():
    # Keep the historic command and shared Lua serializer; the reference now
    # comes from the completed game registry rather than manufactured profiles.
    from export_enchanting import main
    main()


if __name__ == '__main__':
    export()
