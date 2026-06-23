# Extensible Types (XTypes)

Source: https://github.com/weewx/weewx/wiki/xtypes

The XTypes system is the officially sanctioned way to add custom observation and aggregation types to weewx without modifying core code. It can also be used to **replace** built-in derived type calculations like `maxSolarRad`.

---

## Core Architecture

Subclass the abstract base class `weewx.xtypes.XType` and override one to three methods:

- `get_scalar(obs_type, record, db_manager=None)` — calculates individual values for a single record
- `get_series(obs_type, timespan, db_manager, aggregate_type=None, aggregate_interval=None)` — time-series data
- `get_aggregate(obs_type, timespan, aggregate_type, db_manager, **option_dict)` — aggregated values (e.g., daily max)

### Return types

- `get_scalar()` must return a `ValueTuple` (value, unit_string, unit_group), e.g., `ValueTuple(850.0, 'watt_per_meter_squared', 'group_radiation')`
- Raise `weewx.UnknownType` if your extension doesn't handle the requested `obs_type`
- Raise `weewx.CannotCalculate` if the type is known but calculation isn't possible (e.g., missing inputs)

### Registration

Two approaches:

#### 1. Static Registration

Instantiate and append/prepend directly to `weewx.xtypes.xtypes` list:

```python
import weewx.xtypes

my_xtype = MyCustomXType()
weewx.xtypes.xtypes.append(my_xtype)  # runs after built-ins
# OR
weewx.xtypes.xtypes.insert(0, my_xtype)  # runs before built-ins (override)
```

#### 2. Service Registration (recommended for parameterized extensions)

Create a WeeWX service to manage registration with config file support:

```python
import weewx
from weewx.engine import StdService
import weewx.xtypes

class MyXTypeService(StdService):

    def __init__(self, engine, config_dict):
        super().__init__(engine, config_dict)
        # Read config options
        self.my_xtype = MyCustomXType(config_dict)
        # Prepend to run before built-in calculators
        weewx.xtypes.xtypes.insert(0, self.my_xtype)

    def shutDown(self):
        # Clean up on shutdown
        weewx.xtypes.xtypes.remove(self.my_xtype)
```

Register the service in `weewx.conf` under the `xtype_services` group:

```ini
[Engine]
    [[Services]]
        xtype_services = weewx.wxxtypes.StdWXXTypes, weewx.wxxtypes.StdPressureCooker, weewx.wxxtypes.StdRainRater, weewx.wxxtypes.StdDelta, user.my_module.MyXTypeService
```

### Order matters

- **Prepend** (`insert(0, ...)`) to override other extensions or built-in types
- **Append** to supplement (runs after built-ins, used as fallback)
- The first XType that returns a value wins; subsequent ones are skipped for that `obs_type`

### To replace maxSolarRad

1. Create a custom XType subclass that recognizes `obs_type == 'maxSolarRad'`
2. Implement `get_scalar()` with a custom calculation (e.g., using pvlib)
3. Register via a service in the `xtype_services` group, **prepended** so it runs before `StdWXXTypes`
4. The existing `[StdWXCalculate][[Calculations]]` directive `maxSolarRad = prefer_hardware` will still apply — since the XType provides a value, `StdWXCalculate` treats it as "hardware" and won't overwrite it

### Threading safety

If your extension binds to main thread events and shares data structures, use locks. The XType `get_scalar()` is called from the main engine thread.

---

## Example: Vapor Pressure Calculator

The wiki includes a complete example demonstrating the pattern:

```python
import weewx
import weewx.xtypes
import weewx.units
from weewx.engine import StdService

# Register units for the new type
weewx.units.obs_group_dict['vapor_p'] = 'group_pressure'

class VaporPressure(weewx.xtypes.XType):
    """Calculate vapor pressure from temperature and humidity."""

    def get_scalar(self, obs_type, record, db_manager=None):
        if obs_type != 'vapor_p':
            raise weewx.UnknownType(obs_type)

        if record is None:
            raise weewx.CannotCalculate(obs_type)

        temp_C = record.get('outTemp')
        humidity = record.get('outHumidity')

        if temp_C is None or humidity is None:
            raise weewx.CannotCalculate(obs_type)

        # Convert if needed, compute, return ValueTuple
        vp = 6.112 * math.exp((17.67 * temp_C) / (temp_C + 243.5)) * humidity / 100.0
        return weewx.units.ValueTuple(vp, 'mbar', 'group_pressure')


class VaporPressureService(StdService):

    def __init__(self, engine, config_dict):
        super().__init__(engine, config_dict)
        self._vp = VaporPressure()
        weewx.xtypes.xtypes.append(self._vp)

    def shutDown(self):
        weewx.xtypes.xtypes.remove(self._vp)
```
