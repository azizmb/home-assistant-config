const fz = require("zigbee-herdsman-converters/converters/fromZigbee");
const tz = require("zigbee-herdsman-converters/converters/toZigbee");
const exposes = require("zigbee-herdsman-converters/lib/exposes");
const reporting = require("zigbee-herdsman-converters/lib/reporting");
const modernExtend = require("zigbee-herdsman-converters/lib/modernExtend");

const e = exposes.presets;
const ea = exposes.access;

const tuya = require("zigbee-herdsman-converters/lib/tuya");

const definition = {
  // Since a lot of Tuya devices use the same modelID, but use different datapoints
  // it's necessary to provide a fingerprint instead of a zigbeeModel
  fingerprint: [{ modelID: "TS0601", manufacturerName: "_TZE200_cpbo62rn" }],
  model: "LY-1668",
  vendor: "Tuya",
  description: "3in1 Curtain Robot",
  fromZigbee: [tuya.fz.datapoints],
  toZigbee: [tuya.tz.datapoints],
  configure: tuya.configureMagicPacket,
  exposes: [
    e.text("work_state", ea.STATE),
    e.cover_position().setAccess("position", ea.STATE_SET),
    e.battery(),
    e
      .enum("motor_direction", ea.STATE_SET, ["left", "right"])
      .withDescription("Motor side"),
    e
      .enum("set_upper_limit", ea.STATE_SET, ["start", "stop"])
      .withDescription("Learning"),
    e
      .enum("factory_reset", ea.STATE_SET, ["SET"])
      .withDescription("Remove limits"),
    e.temperature(),
    e.illuminance(),
  ],
  whiteLabel: [
    tuya.whitelabel("Tuya", "LY-1668", "3in1 Curtain Robot", [
      "_TZE200_cpbo62rn",
    ]),
  ],
  meta: {
    // All datapoints go in here
    tuyaDatapoints: [
      [
        1,
        "state",
        tuya.valueConverterBasic.lookup({
          CLOSE: tuya.enum(2),
          STOP: tuya.enum(1),
          OPEN: tuya.enum(0),
        }),
      ],
      [2, "position", tuya.valueConverter.coverPositionInverted],
      [3, "position", tuya.valueConverter.coverPositionInverted],
      [
        7,
        "work_state",
        tuya.valueConverterBasic.lookup({
          standby: tuya.enum(0),
          success: tuya.enum(1),
          learning: tuya.enum(2),
        }),
      ],
      [13, "battery", tuya.valueConverter.raw],
      [
        101,
        "motor_direction",
        tuya.valueConverterBasic.lookup({
          left: tuya.enum(0),
          right: tuya.enum(1),
        }),
      ],
      [
        102,
        "set_upper_limit",
        tuya.valueConverterBasic.lookup({
          start: tuya.enum(0),
          stop: tuya.enum(1),
        }),
      ],
      [103, "temperature", tuya.valueConverter.raw],
      [104, "illuminance", tuya.valueConverter.raw],
      [107, "factory_reset", tuya.valueConverter.setLimit],
    ],
  },
};

module.exports = definition;
